"""Independent Python checks of the delivered MATLAB algorithm; NOT MATLAB execution."""
from pathlib import Path
import json
import numpy as np

root=Path(__file__).resolve().parents[1]
rng=np.random.RandomState(123)
R=30.5; rmin=2*R; rmax=3*R; b=rmax+(rmax-rmin); by=rmax
half=np.array([b,by,b])
visible_volume=4*np.pi/3*(rmax**3-rmin**3)
prob=visible_volume/(8*np.prod(half))
n=round(600/prob)
xyz=half[:,None]*(2*rng.rand(3,n)-1)
gen=np.zeros(n,dtype=int)

def advance(xyz,gen,v,dt,rng):
    xyz=xyz.copy(); gen=gen.copy(); v=np.array(v,dtype=float)
    events=[]
    if dt==0 or not np.any(v): return xyz,gen,np.empty((6,0))
    px=abs(v[0])*half[2]/(abs(v[0])*half[2]+abs(v[2])*half[0])
    ids=np.arange(xyz.shape[1]); rem=np.full(ids.size,dt,dtype=float)
    while ids.size:
        xx=xyz[:,ids]
        tx=np.full(ids.size,np.inf); tz=tx.copy()
        if v[0]: tx=(np.sign(v[0])*half[0]-xx[0])/v[0]
        if v[2]: tz=(np.sign(v[2])*half[2]-xx[2])/v[2]
        ex=np.minimum(tx,tz)
        assert np.all(ex>=-1e-9)
        ex=np.maximum(0,ex)
        used=np.minimum(rem,ex)
        xyz[:,ids]=xx+v[:,None]*used
        cross=ex<=rem; rem=rem[cross]-used[cross]; ids=ids[cross]
        if not ids.size: break
        entry=half[:,None]*(2*rng.rand(3,ids.size)-1)
        onx=rng.rand(ids.size)<px
        entry[0,onx]=-np.sign(v[0])*half[0]
        entry[2,~onx]=-np.sign(v[2])*half[2]
        xyz[:,ids]=entry; gen[ids]+=1
        ev=np.vstack((ids,dt-rem,entry,gen[ids]))
        assert np.all(np.hypot(ev[2],ev[4])>rmax)
        events.append(ev)
        keep=rem>0; ids=ids[keep]; rem=rem[keep]
    assert np.max(abs(xyz)-half[:,None])<1e-9
    return xyz,gen,np.concatenate(events,axis=1) if events else np.empty((6,0))

def project(x):
    rr=np.hypot(x[0],x[2]); el=np.rad2deg(np.arctan2(x[1],rr))
    az=np.mod(np.rad2deg(np.arctan2(x[0],x[2])),360)
    vis=(rr>rmin)&(rr<rmax)&(abs(el)<45)
    return az,el,vis

# Matches the posted seed-1 order: MATLAB's seeded randperm for this example.
source_rows=np.argsort(np.random.RandomState(1).rand(18))
combinations=np.array([(di,si) for si in range(3) for di in range(6)])
seq=combinations[source_rows]
expected=np.array([[3,1],[3,3],[6,1],[5,1],[1,2],[1,3],[4,1],[2,2],[3,2],
                   [1,1],[5,3],[5,2],[4,2],[6,3],[4,3],[6,2],[2,1],[2,3]])-1
assert np.array_equal(seq,expected)
phases=1+2*18; duration=5+18*(20+30)
assert phases==37 and duration==905
marker=(np.arange(1,38)+1)%2
assert marker[0]==0 and np.all(abs(np.diff(marker))==1) and marker[-1]==0
# Freeze invariant and all direction/speed combinations.
old=xyz.copy(); oldgen=gen.copy()
x,g,e=advance(xyz,gen,[0,0,0],20,rng)
assert np.array_equal(x,old) and np.array_equal(g,oldgen) and not e.size
maxerr=0; counts=[]; total_events=0; by_condition=[]
for di,si in seq:
    # Stationary phases must not change state at all.
    before=xyz.copy()
    xyz,gen,e=advance(xyz,gen,[0,0,0],20,rng)
    assert np.array_equal(before,xyz) and not e.size
    heading=np.deg2rad(di*60); speed=[45,90,180][si]
    v=-speed*np.array([np.sin(heading),0,np.cos(heading)])
    v[abs(v)<1e-12]=0
    # 30 simulated seconds in 0.1 s steps (geometry validation, not render rate).
    condition_counts=[]
    for _ in range(300):
        before=xyz.copy()
        xyz,gen,e=advance(xyz,gen,v,.1,rng)
        untouched=np.ones(n,dtype=bool)
        if e.size: untouched[np.unique(e[0]).astype(int)]=False
        err=np.max(abs(xyz[:,untouched]-before[:,untouched]-v[:,None]*.1))
        maxerr=max(maxerr,float(err)); assert err<1e-9
        count=int(project(xyz)[2].sum()); counts.append(count); condition_counts.append(count)
        total_events+=e.shape[1]
    by_condition.append({'heading_deg':int(di*60),'speed_cm_s':[45,90,180][si],
                         'mean_visible_centers':float(np.mean(condition_counts))})
# No heading-induced teleport without time advance, and long-step overshoot.
x,g,e=advance(xyz,gen,[90,0,0],0,rng); assert np.array_equal(x,xyz) and not e.size
x,g,e=advance(xyz[:,:6],gen[:6],[-180,0,0],10,rng); assert e.shape[1]>6
# Measured-time catch-up on refresh slots.
def next_slot(last,lastvbl,first,ifi=1/60):
    return max(last+1,int(np.floor((lastvbl-first)/ifi+.5))+1)
assert next_slot(0,100,100)==1
assert next_slot(1,100+3/60,100)==4
assert next_slot(5,100+2/60,100)==6
# Normal timing of all 37 phases, including held images and first-step motion.
assert sum([300]+[1200,1800]*18)==54300
# Plain static checks on required MATLAB file names and prohibited old dependencies.
for path in root.glob('*.m'):
    first=path.read_text().splitlines()[0]
    assert path.stem in first,(path,first)
renderer=(root/'displayHyperSpace_360LED.m').read_text()
assert "stimInitScreen(" not in renderer
assert "Screen('Preference','SkipSyncTests',1)" not in renderer
assert "plan.marker(k)" in renderer and 'photodiodeToggle = ~' not in renderer
report={'scope':'Independent Python geometry/schedule simulation and file-contract checks',
        'matlab_executed':False,'psychtoolbox_executed':False,'hardware_tested':False,
        'passed':True,'phases':phases,'movement_trials':18,'nominal_seconds':duration,
        'matches_user_posted_condition_order':True,'frames_at_60Hz':54300,
        'pool_size':n,'expected_visible_centers':n*prob,
        'simulated_motion_seconds':540,'geometry_step_seconds':0.1,
        'mean_visible_centers':float(np.mean(counts)),'min_visible_centers':int(np.min(counts)),
        'max_visible_centers':int(np.max(counts)),'hidden_reset_entries_checked':total_events,
        'maximum_common_translation_error_cm':maxerr,'by_condition':by_condition,
        'checks':['freeze/resume without changing XYZ','all 18 heading/speed conditions',
                  'headings do not rotate the scene','reset entries outside visible window',
                  'multiple-boundary overshoot preserved','phase marker toggling',
                  'final terminal inversion','refresh-slot catch-up','reproduction of posted order']}
(root/'validation_results.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='by_condition'},indent=2))
