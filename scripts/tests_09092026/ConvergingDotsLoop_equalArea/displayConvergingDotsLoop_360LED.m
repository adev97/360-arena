function runLog = displayConvergingDotsLoop_360LED(trials)
% DISPLAYCONVERGINGDOTSLOOP_360LED Equal-area point-converging loop.
%
% Requires the NEW master and convergingDotsEqualAreaPosition.m.
% This does NOT preserve the old constant-cm/s straight-line motion.
%
% All logical dots remain active. Sizes/colors stay fixed within a trial.
% At each wrap, choose a fresh path beta and optional virtual spawn radius;
% keep fractional phase overshoot. Initial phases are already stationary:
% no numerical warm-up and no arrival-radius exclusion are necessary.
%
% Rendering uses the original gray calibration and batched FillOval.
% Horizontal edge pieces are redrawn across the 0/360-degree seam.
% Top/bottom dot edges are clipped, not vertically wrapped.
%
% Timing: phases use predicted next-VBL time relative to actual onset.
% After a late flip, the next frame catches up instead of slowing the whole
% motion. A frame that was already presented late cannot be corrected;
% modeled times and actual timestamps are both saved. Duration/gray blocks
% are quantized to the measured refresh interval. Any key aborts, as before.
%
% Your existing PixToLum, GammaCorrect, and stimInitScreen are retained.

m = getMonitorInformation();
assert(~isempty(trials), 'The trials array is empty.');
assert(m.screenSizeDegX == 360, 'This mapping requires a full 360-degree width.');
assert(m.screenSizeDegY > 0 && m.screenSizeDegY <= 180, ...
    'Vertical angular range must be in (0,180].');
for k = 1:numel(trials)
    assert(isfield(trials, 'Flow_Model') && ...
        strcmp(trials(k).Flow_Model, 'equalAreaPointFlow_v1'), ...
        'Regenerate trials with the NEW master; old cm/s trials are incompatible.');
    assert(isfield(trials, 'Speed_Units') && ...
        strcmp(trials(k).Speed_Units, 'mean_deg_per_s'), ...
        'Convergence_Speed must be labeled mean_deg_per_s.');
end

oldVerbosity = Screen('Preference', 'Verbosity', 1);
oldVisualDebug = Screen('Preference', 'VisualDebuglevel', 3);
oldPriority = Priority;
cleanupObj = onCleanup(@() localCleanup(oldVerbosity, oldVisualDebug, oldPriority)); %#ok<NASGU>
AssertOpenGL;

whitePix = WhiteIndex(m.screenNumber);
blackPix = BlackIndex(m.screenNumber);
grayPix = GammaCorrect((PixToLum(whitePix) + PixToLum(blackPix))/2);
[w, rect] = Screen('OpenWindow', m.screenNumber, grayPix);
W = RectWidth(rect);
H = RectHeight(rect);
assert(W == m.screenSizePixX && H == m.screenSizePixY, ...
    'Actual window is %gx%g, but monitor settings specify %gx%g. Fix the display mode.', ...
    W, H, m.screenSizePixX, m.screenSizePixY);
HideCursor;
Priority(MaxPriority(w));
ifi = Screen('GetFlipInterval', w);
assert(isfinite(ifi) && ifi > 0, 'Invalid measured flip interval.');

runLog.model = 'equalAreaPointFlow_v1';
runLog.ifiSeconds = ifi;
runLog.screenRect = rect;
runLog.aborted = false;
runLog.trials = cell(1, numel(trials));
stimInitScreen(w, trials(1).Initialization_Screen, grayPix, ifi);

for k = 1:numel(trials)
    tr = trials(k);
    timing = double(tr.Timing(:)');
    assert(numel(timing) == 3 && all(isfinite(timing)) && all(timing >= 0), ...
        'Timing must be [delay duration wait], all finite and nonnegative.');
    isBlank = strcmp(tr.Stimulus_Type, 'Blank');
    nFrames = round(timing(2)/ifi);
    targetDuration = nFrames*ifi;
    aborted = false;

    entry = struct();
    entry.trialNumber = k;
    entry.isBlank = isBlank;
    entry.requestedTimingSeconds = timing;
    entry.quantizedDurationSeconds = targetDuration;
    entry.rngBeforeInitialization = rng;

    if ~isBlank
        localValidateDotParameters(tr);
        N = tr.Num_Dots;
        rMin = tr.Depth_Min;
        rMax = tr.Depth_Max;
        targetDepth = (rMin+rMax)/2;
        loopSeconds = 180/tr.Convergence_Speed;
        phase0 = rand(1, N);
        beta = 2*pi*rand(1, N);
        spawnR = (rMin^3 + (rMax^3-rMin^3)*rand(1, N)).^(1/3);
        diameterPx = tr.Dot_Size_Min + (tr.Dot_Size_Max-tr.Dot_Size_Min)*rand(1, N);
        radiusPx = diameterPx/2;
        colors = blackPix*ones(1, N);
        colors(rand(1, N) < 0.5) = whitePix;
        rgb = repmat(colors, 3, 1);
        lastLap = zeros(1, N);

        entry.loopSeconds = loopSeconds;
        entry.targetDepthCm = targetDepth;
        entry.initialPhase = phase0;
        entry.initialBetaRadians = beta;
        entry.initialSpawnRadiusCm = spawnR;
        entry.dotDiameterPx = diameterPx;
        entry.dotGrayValue = colors;
    end

    modeledTime = nan(1, nFrames);
    vblTimes = nan(1, nFrames);
    onsetTimes = nan(1, nFrames);
    missed = nan(1, nFrames);
    respawns = cell(1, nFrames); % nonempty cells: rows [dot index; beta; radius]

    Screen('FillRect', w, grayPix);
    vbl = Screen('Flip', w);
    entry.delayStartVbl = vbl;
    [vbl, aborted] = localGrayFrames(w, grayPix, vbl, round(timing(1)/ifi), ifi);
    entry.delayEndVbl = vbl;
    firstVbl = NaN;
    nShown = 0;

    if ~aborted
        for f = 1:nFrames
            if f == 1
                elapsed = 0;
            else
                elapsed = vbl + ifi - firstVbl;
                if elapsed >= targetDuration - 0.25*ifi
                    break
                end
            end

            Screen('FillRect', w, grayPix);
            if ~isBlank
                rawPhase = phase0 + elapsed/loopSeconds;
                lap = floor(rawPhase);
                changed = lap > lastLap;
                if any(changed)
                    idx = find(changed);
                    nChanged = numel(idx);
                    beta(idx) = 2*pi*rand(1, nChanged);
                    spawnR(idx) = (rMin^3 + (rMax^3-rMin^3)*rand(1, nChanged)).^(1/3);
                    respawns{f} = [idx; beta(idx); spawnR(idx)];
                    % If frames skipped multiple whole loops, only the final
                    % independent path is needed for the visible state.
                end
                lastLap = lap;
                phase = mod(rawPhase, 1); % preserve overshoot; never reset all to zero
                [az, el] = convergingDotsEqualAreaPosition( ...
                    phase, beta, m.screenSizeDegY/2, spawnR, targetDepth);
                x = W*az/360;
                y = H*(0.5-el/m.screenSizeDegY);
                localDrawWrapped(w, x, y, radiusPx, rgb, W, ceil(tr.Dot_Size_Max));
            end

            [vbl, onset, ~, miss] = Screen('Flip', w, vbl+0.5*ifi);
            if f == 1
                firstVbl = vbl;
            end
            nShown = f;
            modeledTime(f) = elapsed;
            vblTimes(f) = vbl;
            onsetTimes(f) = onset;
            missed(f) = miss;
            if KbCheck
                aborted = true;
                break
            end
        end
    end

    % Explicit gray offset: no old dot frame is left on-screen during ITI.
    Screen('FillRect', w, grayPix);
    vbl = Screen('Flip', w, vbl+0.5*ifi);
    entry.stimulusOnsetVbl = firstVbl;
    entry.stimulusOffsetVbl = vbl;
    entry.actualDurationSeconds = vbl-firstVbl; % NaN if no stimulus frame was shown
    entry.modeledTimeSeconds = modeledTime(1:nShown);
    entry.frameVblTimes = vblTimes(1:nShown);
    entry.frameOnsetTimes = onsetTimes(1:nShown);
    entry.flipMissedSeconds = missed(1:nShown);
    entry.respawnEvents = respawns(1:nShown);
    entry.nRenderedFrames = nShown;
    entry.nPositiveMissedFlags = sum(missed(1:nShown) > 0);
    entry.itiStartVbl = vbl;
    if ~aborted
        [vbl, aborted] = localGrayFrames(w, grayPix, vbl, round(timing(3)/ifi), ifi);
    end
    entry.itiEndVbl = vbl;
    entry.aborted = aborted;
    runLog.trials{k} = entry;
    runLog.aborted = aborted;
    if aborted
        break
    end
end
runLog.nTrialsStarted = k;
% onCleanup closes the screen, restores the cursor/preferences/priority, and
% also runs automatically if an error occurs. Errors are not suppressed.
end

function localDrawWrapped(w, x, y, radiusPx, rgb, W, maxDiameter)
rects = [x-radiusPx; y-radiusPx; x+radiusPx; y+radiusPx];
left = find(x-radiusPx < 0);
right = find(x+radiusPx > W);
leftRects = rects(:, left);
rightRects = rects(:, right);
leftRects([1 3], :) = leftRects([1 3], :) + W;
rightRects([1 3], :) = rightRects([1 3], :) - W;
Screen('FillOval', w, [rgb, rgb(:, left), rgb(:, right)], ...
    [rects, leftRects, rightRects], maxDiameter);
end

function [vbl, aborted] = localGrayFrames(w, grayPix, vbl, nFrames, ifi)
aborted = false;
for f = 1:nFrames
    Screen('FillRect', w, grayPix);
    vbl = Screen('Flip', w, vbl+0.5*ifi);
    if KbCheck
        aborted = true;
        break
    end
end
end

function localValidateDotParameters(tr)
assert(isscalar(tr.Num_Dots) && isfinite(tr.Num_Dots) && ...
    tr.Num_Dots >= 1 && tr.Num_Dots == floor(tr.Num_Dots), ...
    'Num_Dots must be a positive integer.');
assert(isscalar(tr.Depth_Min) && isscalar(tr.Depth_Max) && ...
    isfinite(tr.Depth_Min) && isfinite(tr.Depth_Max) && ...
    tr.Depth_Min > 0 && tr.Depth_Max > tr.Depth_Min, ...
    'Depth radii must satisfy 0 < Depth_Min < Depth_Max.');
assert(isscalar(tr.Dot_Size_Min) && isscalar(tr.Dot_Size_Max) && ...
    isfinite(tr.Dot_Size_Min) && isfinite(tr.Dot_Size_Max) && ...
    tr.Dot_Size_Min > 0 && tr.Dot_Size_Max >= tr.Dot_Size_Min, ...
    'Dot sizes must satisfy 0 < Dot_Size_Min <= Dot_Size_Max.');
assert(isscalar(tr.Convergence_Speed) && isfinite(tr.Convergence_Speed) && ...
    tr.Convergence_Speed > 0, 'Convergence_Speed must be positive, in mean deg/s.');
end

function localCleanup(oldVerbosity, oldVisualDebug, oldPriority)
Priority(oldPriority);
Screen('CloseAll');
ShowCursor;
Screen('Preference', 'Verbosity', oldVerbosity);
Screen('Preference', 'VisualDebuglevel', oldVisualDebug);
end
