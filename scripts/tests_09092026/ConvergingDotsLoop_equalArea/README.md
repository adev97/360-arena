# Equal-area point-converging dots for the 360-degree arena

This is a replacement motion model, not a correction that preserves the old
constant-cm/s physics. It retains a single front target and back source and
provides uniform expected dot-center density in the displayed azimuth/elevation
rectangle. It does not claim perfectly identical pixel occupancy in a finite
random frame, uniform physical solid angle, or uniform 3-D volume density.

## Files and use

Keep these files together on the MATLAB path:

- `ConvergingDotsLoop_master_360dots.m`: replacement master.
- `displayConvergingDotsLoop_360LED.m`: replacement display.
- `convergingDotsEqualAreaPosition.m`: new numerical helper; required.
- `getMonitorInformation.m`: the supplied monitor values, unchanged.
- `testConvergingDotsEqualArea.m`: MATLAB geometry test; no Psychtoolbox required.

Continue using your existing `trialStruct_RFmapFast_AD`, `trialStructSave_360`,
`PixToLum`, `GammaCorrect`, and `stimInitScreen`. Those helpers were not supplied
for execution here and are not replaced. As described in the original master,
the table builder must produce `Convergence_Speed` from the Convergence Speed
row, just as it did before. The unit label changes from `cmps` to `degps`.
The renderer rejects unmarked old trials to prevent silent unit confusion.

Run:

```matlab
report = testConvergingDotsEqualArea();
[trials, meta] = ConvergingDotsLoop_master_360dots('ConvergingDotsLoop_equalArea');
```

The test saves/restores the MATLAB random-number generator state. The actual
stimulus does not force a fixed seed. Initial states, path/radius replacements,
modeled times, and flip timestamps are recorded in `meta.displayLog`.
The existing save helper is called with that metadata using its original
signature. Its handling of nested metadata was not independently inspected.

Replace master and display together, and ensure MATLAB does not find older
copies first (`which displayConvergingDotsLoop_360LED -all`). Any key aborts.
The renderer checks the actual screen dimensions against the supplied 960x240
settings; it does not silently stretch to a different desktop resolution.
Psychtoolbox synchronization checks are not disabled.

## Speed control

`Convergence Speed (degps)` is the MEAN rate of decrease in angular distance
from the target, not instantaneous angular speed:

    traversal time in seconds = 180 / Convergence_Speed

Thus 15 -> 12 seconds, 30 -> 6 seconds, 60 -> 3 seconds. Larger is faster.
The default remains 600 dots, diameters 6-12 pixels, 20-second stimulus and
3-second intertrial wait, with the original initialization/repeat settings.
Instantaneous speed varies with position and path.

## Position map

For each dot, initialize phase p uniformly in [0,1), and path angle beta
uniformly in [0,2*pi). At elapsed time t, phase is `(p0+t/T) mod 1`.
Choose a fresh independent beta when a traversal wraps; preserve fractional
overshoot instead of resetting phase to zero. For the current phase:

    z = 2*p - 1
    q = sqrt(1-z*z)
    auxiliary_x = q*cos(beta)
    auxiliary_y = q*sin(beta)
    azimuth = atan2(auxiliary_x,z), wrapped to [0,360) degrees
    displayed_elevation = 45 * auxiliary_y

At p=0 every path starts at (180 degrees, 0 degrees). As p approaches 1,
every path approaches (0 degrees, 0 degrees). A display frame normally does
not land exactly at either endpoint. The path first fans away from the back
source, then converges to the front; angular distance to the front decreases
throughout. There is no explicit excluded cap or arrival-radius cutoff.

The vertical coordinate is intentionally `45*auxiliary_y`, NOT
`asind(auxiliary_y)`. This is an equal-area mapping onto this rig's
azimuth/elevation rectangle, not an ordinary perspective projection of the
auxiliary sphere. Actual viewer-space paths are generally neither straight
lines nor great circles.

## Why the density is uniform

Uniform p makes z uniform in [-1,1]. Uniform z and beta give uniform area
on the auxiliary unit sphere, with area element:

    dA = dz d(beta) = 2 dp d(beta).

Using azimuth alpha and vertical Cartesian coordinate v on that same sphere:

    dA = d(alpha) dv.

Since displayed elevation e = H*v, H=45 degrees, the absolute mapping
Jacobian in alpha-radians/elevation-degrees coordinates is 2*H. It is constant,
so the display's dot-center density is constant. Uniform phases remain uniform
under translation modulo one; replacing beta with another independent uniform
beta at a wrap preserves the invariant distribution. No warm-up is needed.

Equal screen rectangles therefore have equal expected dot counts. With 600
random dots, individual frames still have sampling noise, overlap, and empty
small regions. Upper/lower circle edges are clipped, so uniform center density
is not a claim of identical rendered luminance at every boundary pixel.

By contrast, constant angular-distance speed on true great circles makes the
population uniform in angular distance theta, not area. Spherical ring area
is proportional to sin(theta), so surface density is proportional to
1/sin(theta), concentrating near BOTH endpoints. Clustering entries around
an exact antipode does not cure that area factor.

## The unavoidable trade-off

An ideal point source or sink, finite density, and nonzero particle flux imply
unbounded speed near the point. This implementation uses finite-frame samples
of that idealized flow. Dots can move noticeably faster close to the source
and target, and projection distortion can also cause fast lateral motion near
the vertical extremes. It is not a bounded-speed, photorealistic flow model.
Increasing frame rate or lowering mean speed reduces temporal jumps but cannot
remove the underlying continuum singularity. Capping speed or adding endpoint
jitter/cutoffs invalidates the exact uniformity proof and changes the model.
Recycling is a teleport with no intentionally blank frame, not an invisible or
physically continuous transition. Do not infer absence of perceptual popping
without inspecting the real arena.

## Virtual-world depth

The old code used r^3 sampling and a spherical XYZ conversion at spawning.
Despite comments calling it a cylinder, these are spherical radial bounds.
It did not enforce those bounds during straight-line movement.

Here an OPTIONAL 3-D embedding is defined by:

    r(p) = (1-p)*spawn_radius + p*target_depth
    target_depth = (Depth_Min+Depth_Max)/2
    X = r*cos(elevation)*sin(azimuth)
    Y = r*sin(elevation)
    Z = r*cos(elevation)*cos(azimuth)

Thus a spawn radius in [2R,3R] stays in that radial shell and ends at the
same front target depth. For R=30.5 cm, bounds are 61-91.5 cm and target depth
is 76.25 cm. This is NOT a cylinder-annulus constraint or a preservation of the
old volumetric distribution. Because this stimulus prescribes screen paths
and fixed pixel diameters, changing depth alone does not change the visible
motion. The renderer requests only angles; request the helper's third output
for the optional 3-by-N XYZ coordinates.

## Rendering and timing changes

All logical dots remain active, with fixed per-trial sizes and black/white
colors. Path and spawn radius, but not size/color, are resampled at each wrap.
There are no tails or retained-frame drawing. Batched FillOval draws the dots,
with the maximum diameter supplied as a performance hint. Circle pieces are
wrapped horizontally at 0/360 degrees, rather than being lost at the seam.
No vertical wrapping or center clamping is applied.

Parameters are read per trial rather than only from trial 1. Blank trials
show their stimulus-duration gray block. The delay field is used. Gray blocks
are held for a refresh-quantized number of frames; trial preparation and
transition overhead can add gray time, especially between trials. Exact onset,
offset, and gray-block timestamps are logged rather than assuming ideal timing.

Stimulus phase uses the next predicted VBL time relative to actual first onset.
Following a late frame, the next frame catches up. A frame already shown late
cannot be repaired: compare modeled time with logged actual VBL/onset times.
Inspect both timestamps and missed-deadline flags before experimental use.
Cleanup restores the cursor, priority, and Screen preferences; errors propagate.

## Validation status

The analytic mapping was derived and independently checked numerically in
Python, including screen-density histograms, endpoint identities, radius bounds,
monotonic approach, wrap handling, and the constant Jacobian. See
`validation_results.json` and `validate_geometry.py` for executed checks.
`testConvergingDotsEqualArea.m` tests the actual MATLAB geometry helper.

MATLAB, Psychtoolbox, the arena, and the lab-specific trial/save/calibration
helpers were NOT available for execution here. The MATLAB self-test and actual
hardware integration have not been run here. Numerical agreement is not proof
of calibrated physical angles, valid gamma correction, or frame-timing quality.

## Primary technical references

Uniform sphere sampling: Physically Based Rendering, 4th edition, Appendix A.5.2.
https://www.pbr-book.org/4ed/Sampling_Algorithms/Sampling_Multidimensional_Functions

Cylindrical equal-area projection: PROJ documentation.
https://proj.org/en/stable/operations/projections/cea.html

Psychtoolbox FillOval and Flip documentation:
https://psychtoolbox.org/docs/Screen-FillOval
https://psychtoolbox.org/docs/Screen-Flip

The flow adaptation, parameterization, code, and uniformity derivation above
are specific to this replacement; the references do not describe this exact
stimulus or validate it on this arena.
