%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function displayLinearSweep_360LED(trials)
% DISPLAYLINEARSWEEP_360LED draws a "hyperspace"-style dot field on the
% 360deg LED arena, one trial at a time from the TRIALS struct built by
% trialStruct_RFmapFast_AD (same pipeline as displayOpticFlow_360LED.m,
% just a different motion pattern).
%
% Each dot has a fixed elevation and a size and color chosen once at
% spawn and never reassigned (no depth-boundary/lifetime respawn like
% OpticFlow -- position, size, and color persist for the whole trial
% except for the azimuth changes described below).
%
% MOTION: during the Sweep phase, every dot's azimuth moves at the same
% constant angular speed, but the SIGN of that motion depends on which
% side of the trial's vanishing-point azimuth the dot started on: dots
% clockwise of the vanishing point keep moving further clockwise (away),
% dots counter-clockwise of it keep moving further counter-clockwise
% (away). This makes the whole field stream apart from that one point,
% rather than rotating together as a rigid block -- the "hyperspace jump"
% look, projected onto the arena's single azimuth dimension.
%
% Cyclic wraparound (a dot disappearing on one edge and reappearing on
% the other) falls out for free: azimuth is wrapped with mod(...,360) at
% every frame, and the pixel mapping already treats azimuth 0 and 360 as
% the same location on the arena.
%
% TRIAL PHASES: Static (dots frozen at spawn) -> Sweep (dots stream apart
% from the vanishing point) -> Freeze (dots frozen at their post-sweep
% position) -> ITI (gray gap before the next repeat).
%
% INPUT: TRIALS - structure array from trialStruct_RFmapFast_AD for
%        stimType 'Linear Sweep', built by LinearSweep_master_360dots.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

monitorInfo = getMonitorInformation();
degPerPix      = monitorInfo.degPerPix; % assumes square angular pixels
screenSizeDegY = monitorInfo.screenSizeDegY;
R_arena        = monitorInfo.radius; % cm

% Stimulus configuration is constant across trials (see master script
% comments on extending Sweep_Direction to vary later); read it once
% from trial 1.
N          = trials(1).Num_Dots;
sizeMin    = trials(1).Dot_Size_Min;
sizeMax    = trials(1).Dot_Size_Max;
staticDur  = trials(1).Static_Duration;
sweepDur   = trials(1).Sweep_Duration;
freezeDur  = trials(1).Freeze_Duration;
itiDur     = trials(1).ITI;
sweepDistCm = trials(1).Sweep_Distance;
directionIdx = trials(1).Sweep_Direction;

% Map direction index (1-6) to a vanishing-point azimuth (deg), relative
% to the mouse's forward view (0 = straight ahead, negative = left).
directionLabels   = {'Front','Front-Left','Back-Left','Back','Back-Right','Front-Right'};
directionAzimuths = [0, -60, -120, 180, 120, 60];
vanishAz = mod(directionAzimuths(directionIdx), 360);

% Convert the linear sweep distance (cm, arc length along the arena
% surface) into a total angular displacement (deg), using the arena
% radius: arc length = radius * angle(rad).
sweepDeg_total = (sweepDistCm / R_arena) * (180/pi);
angularSpeed_degpersec = sweepDeg_total / sweepDur; % same speed applied to every dot

elevMin = -screenSizeDegY/2;
elevMax =  screenSizeDegY/2;

Screen('Preference', 'Verbosity', 1);
Screen('Preference', 'VisualDebuglevel', 3);

try
    AssertOpenGL;

    screenNumber = monitorInfo.screenNumber;
    whitePix = WhiteIndex(screenNumber);
    blackPix = BlackIndex(screenNumber);
    whiteLum = PixToLum(whitePix);
    blackLum = PixToLum(BlackIndex(screenNumber));
    grayLum  = (whiteLum + blackLum) / 2;
    grayPix  = GammaCorrect(grayLum);

    HideCursor;
    [w, screenRect] = Screen('OpenWindow', screenNumber, grayPix); %#ok<ASGLU>

    priorityLevel = MaxPriority(w);
    Priority(priorityLevel);

    ifi        = Screen('GetFlipInterval', w);
    waitframes = 1;
    dt         = waitframes * ifi;

    stimInitScreen(w, trials(1).Initialization_Screen, grayPix, ifi*waitframes);

    exitLoop = 0;
    nTrials  = numel(trials);

    for trial = 1:nTrials
        if exitLoop == 1
            break
        end

        %%%%%%%%%%%%%%%%%%%%%% SPAWN FRESH DOT FIELD %%%%%%%%%%%%%%%%%%%%%%%
        azimuth   = 360 * rand(1, N);
        elevation = elevMin + (elevMax - elevMin) * rand(1, N);
        dotRadiusPix = sizeMin + (sizeMax - sizeMin) * rand(1, N);
        isWhite = rand(1, N) < 0.5;
        dotColorVal = blackPix * ones(1, N);
        dotColorVal(isWhite) = whitePix;

        % Which way each dot moves once the sweep starts: away from the
        % vanishing point, on whichever side it started.
        relAz = mod(azimuth - vanishAz + 180, 360) - 180; % signed, -180 to 180
        moveSign = sign(relAz);
        moveSign(moveSign == 0) = 1; % tie-break for the ~zero-probability case of landing exactly on the vanishing point

        %%%%%%%%%%%%%%%%%%%%%%%%%%% PHASE 1: STATIC %%%%%%%%%%%%%%%%%%%%%%%%
        vbl = Screen('Flip', w);
        nFramesStatic = round(staticDur / ifi);
        for f = 1:nFramesStatic
            vbl = drawDotFrame(w, grayPix, azimuth, elevation, degPerPix, screenSizeDegY, dotRadiusPix, dotColorVal, vbl, waitframes, ifi);
            if KbCheck
                exitLoop = 1;
                break
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%% PHASE 2: SWEEP %%%%%%%%%%%%%%%%%%%%%%%%%
        if exitLoop == 0
            nFramesSweep = round(sweepDur / ifi);
            for f = 1:nFramesSweep
                azimuth = mod(azimuth + moveSign .* angularSpeed_degpersec .* dt, 360);
                vbl = drawDotFrame(w, grayPix, azimuth, elevation, degPerPix, screenSizeDegY, dotRadiusPix, dotColorVal, vbl, waitframes, ifi);
                if KbCheck
                    exitLoop = 1;
                    break
                end
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%% PHASE 3: FREEZE %%%%%%%%%%%%%%%%%%%%%%%%
        if exitLoop == 0
            nFramesFreeze = round(freezeDur / ifi);
            for f = 1:nFramesFreeze
                vbl = drawDotFrame(w, grayPix, azimuth, elevation, degPerPix, screenSizeDegY, dotRadiusPix, dotColorVal, vbl, waitframes, ifi);
                if KbCheck
                    exitLoop = 1;
                    break
                end
            end
        end

        if exitLoop == 1
            break
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ITI %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        vbl = Screen('Flip', w);
        itiFrames = round(itiDur / ifi);
        for f = 1:itiFrames
            Screen('FillRect', w, grayPix);
            vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);
            if KbCheck
                exitLoop = 1;
                break
            end
        end
    end

    Priority(0);
    Screen('CloseAll');

catch
    Screen('CloseAll');
    Priority(0);
    psychrethrow(psychlasterror);
end

Screen('Preference', 'Verbosity', 3);
java.lang.Runtime.getRuntime().gc

return
end

%% ------------------------------------------------------------------
function vbl = drawDotFrame(w, grayPix, azimuth, elevation, degPerPix, screenSizeDegY, dotRadiusPix, dotColorVal, vbl, waitframes, ifi)
% Projects the current azimuth/elevation of every dot to pixel
% coordinates and draws one frame; returns the new vbl timestamp.
xPix = azimuth / degPerPix;
yPix = (screenSizeDegY/2 - elevation) / degPerPix;

dotRects = [xPix - dotRadiusPix; yPix - dotRadiusPix; ...
            xPix + dotRadiusPix; yPix + dotRadiusPix];

Screen('FillRect', w, grayPix);
Screen('FillOval', w, repmat(dotColorVal, 3, 1), dotRects);

vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);
end
