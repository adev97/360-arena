"""Independent numerical counterpart and software preview of the MATLAB model.

Run: python validate_starfield_python.py [--preview]
Requires numpy; preview additionally requires Pillow and ffmpeg on PATH.
This script does not execute or validate MATLAB/Psychtoolbox/the physical rig.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, replace
import json
from pathlib import Path
import subprocess

import numpy as np


@dataclass(frozen=True)
class Parameters:
    count: int = 600
    r_min: float = 61.0
    r_max: float = 91.5
    speed: float = 90.0
    heading: float = 0.0
    geometry: int = 1
    fade: float = 7.625
    edge_fade: float = 1.5
    half_fov: float = 45.0
    size_min: float = 2.0
    size_max: float = 4.0
    width: int = 960
    height: int = 240


def initialize(p: Parameters, rng: np.random.Generator) -> dict:
    if p.geometry not in (1, 2):
        raise ValueError('geometry must be 1 (cylinder) or 2 (sphere)')
    factor = (np.tan if p.geometry == 1 else np.sin)(np.deg2rad(p.half_fov))
    bx, by, bz = p.r_max, p.r_max * factor, 2 * p.r_max - p.r_min
    volume = 4 * np.pi / 3 * factor * (p.r_max**3 - p.r_min**3)
    probability = volume / (8 * bx * by * bz)
    n = round(p.count / probability)
    return dict(p=p, rng=rng, n=n, bx=bx, by=by, bz=bz,
                probability=probability,
                q=bx * (2 * rng.random(n) - 1),
                y=by * (2 * rng.random(n) - 1),
                phase0=2 * bz * rng.random(n),
                diameter=p.size_min + (p.size_max - p.size_min) * rng.random(n),
                lap=np.zeros(n, dtype=np.int64), last_t=0.0)


def smoothstep(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0, 1)
    return x*x*(3-2*x)


def evaluate(s: dict, t: float) -> dict:
    if not np.isfinite(t) or t < s['last_t']:
        raise ValueError('Time must be finite, nonnegative, and nondecreasing')
    p = s['p']
    length = 2*s['bz']
    distance = s['phase0'] + p.speed*t
    lap = np.floor(distance/length).astype(np.int64)
    changed = lap > s['lap']
    ids = np.flatnonzero(changed)
    s['q'][changed] = s['bx']*(2*s['rng'].random(len(ids))-1)
    s['y'][changed] = s['by']*(2*s['rng'].random(len(ids))-1)
    s['lap'] = lap
    s['last_t'] = t
    z = s['bz']-np.remainder(distance, length)
    h = np.deg2rad(p.heading)
    x_world = s['q']*np.cos(h)+z*np.sin(h)
    z_world = -s['q']*np.sin(h)+z*np.cos(h)
    rho = np.hypot(s['q'], z)
    az = np.remainder(np.rad2deg(np.arctan2(s['q'], z))+p.heading, 360)
    el = np.rad2deg(np.arctan2(s['y'], rho))
    depth = rho if p.geometry == 1 else np.hypot(rho, s['y'])
    contrast = (smoothstep((depth-p.r_min)/p.fade)
                * smoothstep((p.r_max-depth)/p.fade)
                * smoothstep((p.half_fov-np.abs(el))/p.edge_fade))
    return dict(xyz=np.vstack((x_world,s['y'].copy(),z_world)), z=z,
                az=az, el=el, depth=depth, contrast=contrast,
                visible=contrast>0, resets=ids, t=t)


def angle_difference(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.rad2deg(np.arctan2(np.sin(np.deg2rad(a-b)),np.cos(np.deg2rad(a-b))))


def validate() -> dict:
    results = dict(model='starfieldTranslation_v1', implementationExecuted='independent Python counterpart',
                   matlabExecuted=False, psychtoolboxExecuted=False, hardwareTested=False,
                   geometries=[])
    for geometry in (1, 2):
        p = Parameters(geometry=geometry)
        s = initialize(p,np.random.default_rng(11))
        f0 = evaluate(s,0)
        f1 = evaluate(s,.001)
        unwrapped = np.ones(s['n'],bool)
        unwrapped[f1['resets']] = False
        h = np.deg2rad(p.heading)
        velocity = -p.speed*np.array([np.sin(h),0,np.cos(h)])
        error = f1['xyz'][:,unwrapped]-f0['xyz'][:,unwrapped]-velocity[:,None]*.001
        max_error = float(np.max(np.abs(error)))
        assert max_error<1e-10
        use = unwrapped & f0['visible'] & f1['visible']
        a0 = angle_difference(f0['az'],p.heading)
        da = angle_difference(f1['az'],f0['az'])
        assert (da[use & (a0>0)]>0).all() and (da[use & (a0<0)]<0).all()
        d = f0['depth'][f0['visible']]
        assert (d>p.r_min).all() and (d<p.r_max).all()
        xyz = f0['xyz'][:,f0['visible']]
        omega = np.linalg.norm(np.cross(xyz.T,velocity),axis=1)/np.sum(xyz**2,axis=0)
        assert (omega<=p.speed/p.r_min+1e-12).all()
        wrap = initialize(p,np.random.default_rng(14))
        length = 2*wrap['bz']
        wrap['phase0'][0] = length-1e-4
        b = evaluate(wrap,0)
        a = evaluate(wrap,2e-4/p.speed)
        assert b['contrast'][0]==a['contrast'][0]==0 and 0 in a['resets']
        t=3.25*length/p.speed
        late=evaluate(wrap,t)
        expected=wrap['bz']-np.remainder(wrap['phase0']+p.speed*t,length)
        assert np.max(np.abs(late['z']-expected))<1e-12
        base=initialize(p,np.random.default_rng(21))
        normal=evaluate(base,0)
        for heading in (0,-60,-120,180,120,60):
            base['p']=replace(p,heading=heading)
            rotated=evaluate(base,0)
            assert np.max(np.abs(angle_difference(rotated['az'],normal['az']+heading)))<1e-10
            assert np.array_equal(rotated['contrast'],normal['contrast'])
        base['p']=p
        base['phase0']=np.remainder(2*base['bz']-base['phase0'],2*base['bz'])
        reflected=evaluate(base,0)
        symmetry_error=float(np.max(np.abs(reflected['contrast']-normal['contrast'])))
        assert symmetry_error<1e-10
        large=initialize(replace(p,count=100000),np.random.default_rng(123))
        f=evaluate(large,0)
        counts=np.histogram(f['az'][f['visible']],bins=np.arange(0,361,10))[0]
        assert counts.min()>0
        rel=angle_difference(f['az'],p.heading)
        front=int(np.count_nonzero(f['visible'] & (np.abs(rel)<30)))
        back=int(np.count_nonzero(f['visible'] & (np.abs(rel)>150)))
        results['geometries'].append(dict(geometry=geometry,normalPoolSize=s['n'],
            normalExpectedVisibleCount=s['n']*s['probability'],
            maxTranslationErrorCm=max_error,maxFrontBackContrastError=symmetry_error,
            largeTestPoolSize=large['n'],largeTestVisibleCount=int(f['visible'].sum()),
            largeTestExpectedVisibleCount=large['n']*large['probability'],
            azimuthBinCounts=counts.tolist(),
            azimuthRelativeRMS=float(np.sqrt(np.mean((counts/counts.mean()-1)**2))),
            frontCount=front,backCount=back,frontBackRatio=front/back,
            maxSampledAngularSpeedDegps=float(np.rad2deg(omega.max())),
            boundAngularSpeedDegps=float(np.rad2deg(p.speed/p.r_min)),
            directionBoundsWrapOvershootHeadingAndSymmetryPassed=True))
    p=Parameters(speed=0)
    s=initialize(p,np.random.default_rng(4))
    a=evaluate(s,0)
    b=evaluate(s,1000)
    assert np.array_equal(a['xyz'],b['xyz']) and not len(b['resets'])
    results['zeroSpeedPassed']=True
    results['numericalTestsPassed']=True
    return results


def preview(folder: Path, seconds: float=10, fps: int=60) -> None:
    from PIL import Image, ImageDraw
    p=Parameters()
    s=initialize(p,np.random.default_rng(1))
    header=48
    width,height=p.width,p.height+header
    output=folder/'preview_starfield_360.mp4'
    cmd=['ffmpeg','-y','-hide_banner','-loglevel','error','-f','rawvideo',
         '-vcodec','rawvideo','-pix_fmt','rgb24','-s',f'{width}x{height}',
         '-r',str(fps),'-i','-','-an','-c:v','libx264','-preset','fast',
         '-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(output)]
    process=subprocess.Popen(cmd,stdin=subprocess.PIPE)
    observed=[]
    try:
        for i in range(round(seconds*fps)):
            f=evaluate(s,i/fps)
            keep=f['visible']
            ids=np.flatnonzero(keep)
            ids=ids[np.argsort(f['contrast'][ids])]
            panel=Image.new('L',(2*p.width,2*p.height),0)
            draw=ImageDraw.Draw(panel)
            xs=np.remainder(f['az'][ids]+180,360)*p.width/360
            ys=(.5-f['el'][ids]/(2*p.half_fov))*p.height
            for idx,x,y in zip(ids,xs,ys):
                diameter=s['diameter'][idx]
                radius=diameter/2
                value=round(255*f['contrast'][idx]**(1/2.386))
                for shifted in (x,x-p.width,x+p.width):
                    if shifted+radius<0 or shifted-radius>p.width:
                        continue
                    draw.ellipse((2*(shifted-radius),2*(y-radius),
                                  2*(shifted+radius),2*(y+radius)),fill=value)
            panel=panel.resize((p.width,p.height),Image.Resampling.LANCZOS)
            img=Image.new('RGB',(width,height),(0,0,0))
            img.paste(panel,(0,header))
            text=ImageDraw.Draw(img)
            text.text((10,3),f'SOFTWARE PREVIEW | forward travel {p.speed:g} cm/s | full 3-D | front centered | t={i/fps:04.1f}s',fill=(230,230,230))
            for x,label in ((4,'BACK 180'),(218,'LEFT 270'),(451,'FRONT 0'),(696,'RIGHT 90'),(899,'BACK 180')):
                text.text((x,27),label,fill=(160,160,160))
            if i==round(3*fps):
                img.save(folder/'preview_frame.png')
            process.stdin.write(img.tobytes())
            observed.append(int(keep.sum()))
    finally:
        process.stdin.close()
        returncode=process.wait()
    if returncode:
        raise RuntimeError(f'ffmpeg returned {returncode}')
    stats=dict(seconds=seconds,fps=fps,frames=len(observed),
               meanVisible=float(np.mean(observed)),minVisible=min(observed),
               maxVisible=max(observed),simulatedNotHardware=True)
    (folder/'preview_statistics.json').write_text(json.dumps(stats,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--preview',action='store_true')
    args=parser.parse_args()
    folder=Path(__file__).resolve().parent
    report=validate()
    (folder/'validation_results.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))
    if args.preview:
        preview(folder)
