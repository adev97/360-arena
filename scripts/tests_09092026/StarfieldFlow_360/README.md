# 360-degree star-field translational optic flow

This is a new motion model, not a tuning of the equal-area convergence code.
Run `StarfieldFlow_master_360dots`, not `ConvergingDotsLoop_master_360dots`.
Keep all new MATLAB files together on your MATLAB path. You can retain the
old convergence files for comparison; the function names are distinct.

## Run

```matlab
report = testStarfieldFlow360();     % no Psychtoolbox required
[trials, meta] = StarfieldFlow_master_360dots('StarfieldFlow_firstTest');
```

Press **ESC** to abort. Defaults are test mode (`iftest = 1`), 5 seconds of
initialization, 20 seconds of dots, 3 seconds of inter-trial background, and
`Repeats = 1` (two base trials under the supplied description of your builder).
The existing lab save helper is called even after a normal ESC abort.
A runtime error is not silently caught or replaced with a fallback stimulus.

Existing dependencies, unchanged and not re-created here:
`trialStruct_RFmapFast_AD`, `trialStructSave_360`, `PixToLum`, `GammaCorrect`,
`stimInitScreen`, and Psychtoolbox. The supplied `getMonitorInformation.m`
is a copy of the settings in this conversation. Keep your calibrated local
version if it has since changed. The renderer refuses a window whose size
is not the specified 960 by 240 pixels; it does not silently scale the rig.

## Main controls

Edit the `MAIN CONTROLS` block in the new master. Edit `p`, not an isolated
numeric value in the generated table: the master explicitly copies those
constant parameters into every trial. This makes the settings unambiguous
even when the lab trial builder creates sparse Blank entries.

| Control | Default | Meaning |
|---|---:|---|
| `p.Num_Dots` | 600 | Target **mean** number of centers in the depth/FOV window, before attenuation. |
| `p.Travel_Speed` | 90 | Common simulated observer speed in cm/s. 180 is twice as fast; 0 is static. |
| `headingList` | 0 | Direction of simulated travel; positive follows increasing arena azimuth. |
| `p.Depth_Min` | 61 cm | Inner visible radius, 2 times the arena radius. |
| `p.Depth_Max` | 91.5 cm | Outer visible radius, 3 times the arena radius. |
| `p.World_Geometry` | 1 | 1 = vertical cylindrical annulus; 2 = spherical radial shell. |
| `p.Dot_Size_Min/Max` | 2 / 4 px | Constant per-star pixel **diameters**, not radii. |
| `p.Boundary_Fade` | 7.625 cm | Smooth contrast taper at each radial boundary. |
| `p.Vertical_Edge_Fade` | 1.5 deg | Thin contrast taper at the top and bottom of the display. |
| `p.Dark_Background` | 1 | White stars on black. 0 restores random black/white on calibrated mean-luminance gray. |
| `randomSeed` | 1 | Reproducible seed; the caller's RNG state is restored after the master returns. |

To use your six directions:

```matlab
headingList = [0, -60, -120, 180, 120, 60];
randomizeHeadingOrder = true;
```

Each nonblank base trial is expanded into one trial per heading; each base
trial's heading order is shuffled independently. Blank trials are retained
once. With two nonblank base trials, that makes 12 stimulus trials. The
per-trial `Heading`, `Sequence_Index`, and `Base_Trial_Index`, together with
`meta.headingList`, describe the actual order. The single constant Heading
entry in the original table describes the base template only.

Full 3-D projection is intentional: both azimuth and elevation change. This
version does not freeze elevation or impose azimuth-only movement.

## Physical model and projection

Coordinates follow the original renderer: +Z is azimuth 0 degrees, +X is
azimuth 90 degrees, and +Y is upward. For heading h and speed v:

```
d[X;Y;Z]/dt = -v * [sin(h);0;cos(h)]
azimuth   = mod(atan2d(X,Z),360)
elevation = atan2d(Y,hypot(X,Z))
```

These are straight, parallel star paths in observer coordinates, equivalent
to the observer moving through stationary points. At heading 0 the rule is
simply `Z = Z - v*dt`, with X and Y unchanged until an invisible reservoir
reset. The front expands, the sides sweep rearward, and the back contracts.
No star is steered toward a finite target. Constant physical velocity is
not constant angular velocity. Dot diameters remain fixed in pixels: this
is a motion-cue stimulus without perspective size scaling, physical stellar
brightness falloff, or tails.

The actual LED mapping retains the supplied rig's **linear azimuth/elevation
mapping**. It does not introduce or validate a physical cylindrical-screen
height correction, panel ordering, viewpoint calibration, or gamma table.
On the actual arena, verify that your chosen numeric heading is physically
in front of the mouse. At heading 0, the front lies at the 0/360 image seam;
that seam is adjacent around the arena, not two distinct physical sources.

## How 2R-3R bounds and continuous replenishment coexist

The bounds define the **rendered depth window**. They are not walls that
stars bounce off, nor limits imposed by bending their trajectories.

- Geometry 1 uses `Depth_Min < hypot(X,Z) < Depth_Max`: a vertical cylinder.
- Geometry 2 uses `Depth_Min < sqrt(X^2+Y^2+Z^2) < Depth_Max`: a sphere.

A larger rectangular reservoir holds unseen stars. Its half-extents in
heading coordinates are X = rMax; Z = rMax + (rMax-rMin); and Y =
rMax*tan(verticalHalfFOV) for the cylinder, or rMax*sin(verticalHalfFOV) for
the sphere. The Z boundary is strictly beyond the visible outer radius.
The reservoir is initially uniform by volume, including uniform longitudinal
phases, so no startup warm-up or synchronized global respawn is required.

At a rear reservoir crossing, a star wraps to the front, retaining its
fractional overshoot. Only its lateral position and height are re-sampled;
its pixel diameter and polarity persist for the trial. Both endpoints are
invisible. Between resets all stars have exactly the same displacement.
The radial window and a smoothstep contrast envelope hide the near/far
visibility transitions. A star may disappear into the inner unrendered
region and emerge behind; it is **not** teleported at that inner boundary.

A finite depth window necessarily makes stars enter/leave visibility.
Fades reduce abrupt appearance; this is not a promise that an individual
star stays visible continuously for its entire front-to-back passage, or
that every fade will be perceptually undetectable. Larger speeds shorten
fades in time. Increasing Boundary_Fade softens them but cannot exceed half
the window thickness. Increasing the visible depth range changes the
stimulus and should be documented when used experimentally.

## Density

`Num_Dots` is not a hard cap on the reservoir. The code chooses its size from

```
pVisible = visibleVolume / reservoirVolume
nPool = round(Num_Dots / pVisible)
```

For a half-height E, the displayed volumes are
`(4*pi/3)*tan(E)*(rMax^3-rMin^3)` for the cylinder and
`(4*pi/3)*sin(E)*(rMax^3-rMin^3)` for the sphere. Degrees are used in code.
Thus the target is the expected count in the actual depth/FOV window, not
an unexplained fixed reservoir count. Actual visible counts fluctuate;
contrast fading further lowers the apparent number of bright stars.

The sampling/visibility model is symmetric front-to-back and has no
front/back exclusion cone. It is uniform in visible world volume before
fades, not uniform in display pixels. The cylindrical model has elevation
density proportional to sec(elevation)^2 before edge taper; the spherical
model has elevation density proportional to cos(elevation). Both have
uniform expected azimuth counts. Nothing normalizes or distorts velocities
to enforce equal per-frame screen density. Finite random frames can still
contain empty patches or overlapping dots.

## Rendering and timing

The display uses batched shader-based round anti-aliased `Screen('DrawDots')`
with `dot_type = 3` and alpha blending for circle edges. Complete frames
are cleared, so no trails accumulate. Circles crossing the 0/360-degree
seam are also drawn on the other side. There is no vertical wrapping.

The lab `PixToLum` and `GammaCorrect` helpers build luminance-interpolated
contrast LUTs before the run. GPU edge/overlap blending can still depend on
the framebuffer gamma configuration; the code does not certify calibrated
luminance merely because it uses those helpers. LUT outputs outside the
native pixel range are rejected rather than silently clipped.

Rendering uses the measured refresh interval and predicts the next VBL.
After a missed frame the next model time catches up with elapsed time.
An already displayed late frame cannot be corrected. Requested durations
are quantized to whole refreshes and actual times are recorded. The first
stimulus can only appear at the next refresh after preparation. Requested
zero ITI still has one blank offset refresh; positive ITIs are held so the
next trial's first flip completes the final requested interval. Any next
trial delay and overruns are reflected in `actualInterTrialGapSeconds`.

The code never enables `SkipSyncTests`; it refuses to run with that global
preference enabled. Press ESC to abort. On cleanup it closes PTB windows,
restores the cursor, and restores priority/preferences.

`meta.displayLog.trials{k}` stores initial world state, RNG state, model
times, VBL/onset/completion timestamps, missed-deadline flags, visible/drawn
center counts, and reset events `[poolID; newLateral; newHeight; lap]`.
Those records, and the source text saved in meta, support later inspection.
`hardwareValidated` remains false: executing the display is not a validation
of physical LED timing or photometry.

## Validation and preview

`testStarfieldFlow360.m` tests the actual MATLAB geometry helper when run on
your machine: common 3-D displacement, front expansion/back contraction,
radial bounds, finite visible angular-speed bound, invisible recycling,
overshoot across multiple cycles, six-heading covariance, front/back
contrast symmetry, angular coverage, and the zero-speed case.

`validate_starfield_python.py` is the separately executed Python numerical
implementation used here, not MATLAB execution. Its results are in
`validation_results.json`. `preview_starfield_360.mp4` is an unwrapped
software illustration from that implementation with the front centered.
The actual renderer keeps the original 0-degree-at-left mapping. The preview
is not a recording of Psychtoolbox or the LED arena, and its apparent
brightness is not a photometric calibration.

MATLAB, Psychtoolbox, the lab helpers, and the physical arena were not
available for execution here. Run the MATLAB test, then a brief test-mode
arena run, and inspect motion, physical heading, calibration and flip logs.

## API references checked for implementation

- Psychtoolbox DrawDots: https://psychtoolbox.org/docs/Screen-DrawDots
- Psychtoolbox BlendFunction: https://psychtoolbox.org/docs/Screen-BlendFunction
- Psychtoolbox Flip: https://psychtoolbox.org/docs/Screen-Flip

These document rendering and timestamp semantics, not validation of this
particular rig or the custom mathematical model.
