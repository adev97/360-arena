# HyperSpace — continuous 360-degree optic-flow protocol

This is a runnable MATLAB/Psychtoolbox implementation, **not just the earlier schedule builder**. Keep it in a new folder; it does not require or replace any `StarfieldFlow` functions.

## Files and entry points

- `makeHyperSpaceProtocol.m`: edit directions, speeds, sequence, phase durations, block count, randomization, and order seed. Calling this function alone only previews the plan.
- `HyperSpace_master_360dots.m`: edit dot appearance, world bounds, world seed, experiment identifiers, and saving options. This is the main arena entry point.
- `displayHyperSpace_360LED.m`: continuous display and phase/frame logging, including phase-boundary photodiode patches.
- `HyperSpaceWorld.m`: persistent XYZ coordinates, projection, fades, and hidden recycling for arbitrary horizontal velocities.
- `HyperSpaceFrameClock.m`: shared refresh quantization and late-frame scheduling logic.
- `testHyperSpace.m`: MATLAB numerical tests, without Psychtoolbox or acquisition.
- `runHyperSpaceShortTest.m`: an 11-second actual-arena test plus finalization time.
- `validation_results.json`: results of an independently executed Python simulation. These are **not** results from MATLAB or an arena.
- `validation/validate_independent.py`: the executed independent geometry/schedule validation, included for inspection.

Required existing rig helpers: `getMonitorInformation`, `PixToLum`, `GammaCorrect`, `LeftBoxStim_small`, `trialStructSave_360`, and `dirInformation_AD`. Keep your existing calibrated versions. No new calibration, detector placement, or physical panel mapping is guessed. Psychtoolbox must be installed and synchronization tests enabled. The master does not automatically change timestamp preferences.

The new master intentionally does **not** call `trialStruct_RFmapFast_AD` or `stimInitScreen`. The explicit phase schedule replaces their repetition/timing role. There is no implicit initialization countdown or ITI.

## Run

Add this folder and your existing rig helpers to the MATLAB path, then:

```matlab
% Geometry/schedule only — does not open the display.
report = testHyperSpace();

% Preview the complete experiment — does not open the display.
[protocol, design] = makeHyperSpaceProtocol();

% An actual short arena test, without modifying the long default design.
[trials, meta] = runHyperSpaceShortTest();

% The full experiment, using the previewed design.
[trials, meta] = HyperSpace_master_360dots('HyperSpace_run01', design);
```

Start Open Ephys recording separately. This package neither starts/stops OneBox acquisition nor reads the photodiode voltage. Press ESC to stop a presentation; the master saves known data.

The short test uses 1 s black, 2 s stationary, 3 s moving at 0 degrees/45 cm/s, 2 s stationary, and 3 s moving at 180 degrees/180 cm/s. Its order is deliberately fixed. Normal full-run randomization remains enabled.

## Current full design

```matlab
design.InitialBlack_s = 5;
design.Stationary_s = 20;
design.Motion_s = 30;
design.Directions_deg = [0, 60, 120, 180, 240, 300];
design.Speeds_cm_s = [45, 90, 180];
[d,s] = ndgrid(1:numel(design.Directions_deg),1:numel(design.Speeds_cm_s));
design.Sequence = [d(:),s(:)];
design.BlockRepeats = 1;
design.RandomizeWithinBlock = true;
design.Seed = 1;
```

This is 37 phases, 18 movement trials, and 905 nominal seconds (15 min 5 s). Every condition appears once per block. Each stationary/movement pair stays together when shuffled. Seed 1 reproduces the same order across repeated runs; use another `design.Seed` for a different reproducible order. `worldSeed` in the master controls star generation separately.

A sequence row contains **indices**, not physical heading/speed values. The stationary phase's `Condition` labels its upcoming movement; it does not move in that condition. Nonmoving heading is `NaN` and speed is zero.

Modify the design inside the builder, or edit the returned `design` and pass it into the master. The master rebuilds the phase table using those edits. A saved/previewed table does not rebuild merely because a variable changes elsewhere.

## Motion and visual continuity

Stars have one persistent world state. Coordinates are fixed to the arena: +Z = 0 degrees, +X = 90 degrees, +Y = up. During movement, every unrecycled star shares

```matlab
velocityXYZ = -speed * [sind(heading); 0; cosd(heading)];
```

Heading changes change the velocity, not a rotation of the positions. Speed is physical virtual-world cm/s, not deg/s. At a stationary boundary, the renderer holds the exact last generated and successfully drawn star image, including dot size, color, fading, and visibility. There are no inserted blank frames between stationary and moving phases. At movement onset, the first moving frame advances one measured refresh at the new velocity, so the patch transition accompanies a changed star image rather than a duplicate zero-displacement frame.

The appearance defaults remain 600 expected visible centers before fades, 2–4 px diameters, white on black, a cylindrical visible annulus from 2R to 3R, depth fades over 25% of the window at each boundary, and a 1.5-degree vertical edge fade. Stars can still disappear at radial cutoffs **inside** the screen; this package does not remove the earlier depth/fade rules or make every star continuously visible. Sizes stay fixed; no streaks or perspective size growth.

The invisible reservoir is now a fixed box supporting all headings. Stars exit at a box face and re-enter at an upstream face. Face selection is weighted by incoming volume flux (normal speed times face area); residual motion after a reset is retained. Both reset endpoints are outside the visible radial window. This change is necessary because the old helper's heading-dependent local-coordinate representation cannot simply switch heading without rotating its scene. New hidden entries are not a globally reversible, infinite pre-generated universe; reversing the observer can eventually encounter renewed stars.

Expected occupancy is uniform in the chosen reservoir volume, **not necessarily in display pixels**. Visible counts fluctuate; increasing counts or enforcing exact pixel density is not part of this change.

## Photodiode option 1

The renderer draws your existing `LeftBoxStim_small` after the star field and before the same flip that presents it. It never invents new patch coordinates.

| Phase | Main display | Commanded patch value |
|---|---|---:|
| Initial black | Black | 0, black |
| Stationary | Frozen current stars | 1, white |
| Movement | Moving stars | 0, black |
| Next stationary | Frozen current stars | 1, white |
| Next movement | Moving stars | 0, black |

Brightness is constant within each phase, not alternating per frame. `PhotodiodeValue` is a commanded black/white state, not a measured voltage or a guarantee about detector polarity. Keep the patch optically hidden from the mouse.

**Initial black has no unique optical onset:** the screen was already black during hardware preparation. The first black-to-white optical edge is phase 2, when stationary stars appear. Phase 1 onset is saved in PTB time but is not independently marked by this waveform.

**Final movement offset is explicitly marked:** since the last movement patch is black, the renderer hides the stars and switches the patch to white. This is `meta.displayLog.terminal`, outside the 37-phase experiment. It holds for 0.5 s by default, then explicitly switches to black (`cleanupBlack`) and waits 0.25 s before closing the display. Thus there is a further cleanup edge after the terminal edge; do not count it as an extra trial. The nominal 905 s excludes these ~0.75 s of housekeeping and hardware setup. Closing the window can expose the desktop; discard later diode changes.

At ESC, the terminal marker inverts the last actually displayed phase level; its polarity depends on the interrupted phase. After a drawing error, an optical terminal marker may be unavailable. The log does not fabricate one.

There are 36 internal phase-boundary edges, plus one terminal edge, for the default completed run. The initial black starts without an edge; the cleanup edge is separate. When measured marker edges are complete and the first stationary onset is identified, match phase IDs 2…37 to successive internal edges; the next edge is terminal. This is not a coded identifier scheme, and it does not validate per-frame delivery. Record from before stimulus onset; detect BOTH polarities and inspect extra/missing edges rather than silently counting through them.

## Saving and locating onsets

The master saves both `trials` and `meta` to:

1. An explicit additional file under `fullfile(pwd,'HyperSpace_logs')`; its full name is printed and saved as `meta.localLogFile`. Choose a directory on an actual local disk when editing this setting if independence from the network destination matters.
2. Your original `trialStructSave_360`, which uses `dirInfo.DaqPCDataLoc`. Your `iftest=1` appends `_test`; it does not disable saving.

The additional copy uses MAT v7.3. Both copies include the requested design, randomized order, source text, initial world, per-phase states, software marker states, recorded flip timestamps, and reset records. No hardware voltage is inside these logs.

```matlab
% Easy top-level motion-trial summary (also saved as struct array 'trials'):
meta.movementTrials

% Actual start/stop timestamps for every phase:
meta.displayLog.phases(:, {'PhaseID','TrialID','Mode','Condition', ...
    'PhotodiodeValue','OnsetPTB_s','OffsetPTB_s','ActualDuration_s','Completed'})

% Per-frame log:
meta.displayLog.frames

% End-of-run marker and subsequent cleanup:
meta.displayLog.terminal
meta.displayLog.cleanupBlack

% First movement's software onset:
trials(1).MovementOnsetPTB_s
```

All `PTB`/`VBL` timestamps are on the stimulus computer's clock. They are **not OneBox seconds**. The physical ADC trace must be matched to these marker events, and ADC/probe time bases must be synchronized separately. The code does not analyze or relabel the recorded voltage automatically.

Each phase's offset is the next phase's first displayed frame, without an intermediate blank flip. The terminal frame ends the final phase. Incomplete phases are marked `Completed=false`; unstarted onsets remain NaN.

## Timing and failure handling

Durations are rounded to a whole number of measured display refreshes. The log retains both requested and quantized durations. The scheduler uses actual VBL timestamps to estimate elapsed refresh slots after late frames; motion catches up on that grid. It cannot repair an already-late image. Whole phases are not silently skipped to recover a global end time; an overrun can extend the run. Actual onset/offset logs are authoritative for software timing, and the diode measures local light output.

The first moving frame advances one refresh. Subsequent motion updates record the exact `ModelAdvance_s`; stationary/black updates are zero. A late-frame catch-up can produce a larger visible motion step, which remains a stimulus-delivery issue even with a phase photodiode. Hardware timing and whether VBL timestamp fallback is adequate remain unverified here.

Partial logs are saved after ESC and after caught display errors. The master rethrows errors after saving; it does not hide them. If the lab save fails, the explicit additional copy already exists. There is no in-run disk checkpointing: a MATLAB/process crash, power loss, or forced termination can lose the run. Timing-critical loops do not perform file I/O.

## Validation status

An independent Python implementation was executed over all 18 conditions (540 s of simulated movement in 0.1 s geometry steps). It checked freeze invariance, shared translations, arbitrary heading changes, hidden inflow boundaries, multiple-boundary overshoot, phase counts, the posted seed-1 order, and refresh-slot behavior. Expected count was about 600.01; mean sampled visible count was about 599.73. These are numerical simulation results, not observations of the physical arena.

**MATLAB, Psychtoolbox, the lab helpers, the photodiode, and OneBox were not executed here.** Run `testHyperSpace` on the stimulus PC and then the short arena test before the long experiment. The included MATLAB tests exercise the same world/clock helpers used by the new renderer, but do not test hardware integration.

## Documentation references

Official API references used while preparing the integration (these do not validate the custom renderer):

- Psychtoolbox `Screen('Flip')`: https://psychtoolbox.org/docs/Screen-Flip
- Psychtoolbox `Screen('DrawDots')`: https://psychtoolbox.org/docs/Screen-DrawDots
- MathWorks `save`: https://www.mathworks.com/help/matlab/ref/save.html
