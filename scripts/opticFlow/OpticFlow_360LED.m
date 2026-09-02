%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function OpticFlow_360LED(trials)
% OPTICFLOW_360LED draws a forward-self-motion optic flow dot field on
% the 360deg LED arena, one trial at a time from the TRIALS struct built
% by trialStruct_RFmapFast (same pipeline as ReceptiveFieldMapping_Fast_
% polar.m, just a different stimulus).
%
% Each dot has a 3D position (X,Y,Z) relative to the mouse in a virtual
% world; every frame Z shrinks at a constant rate (forward translation
% through a static dot cloud), then the dot is projected straight to
% arena azimuth/elevation via spherical coordinates -- the arena IS the
% angular coordinate system, no flat-screen/tangent-plane projection
% needed here (contrast with the earlier flat-monitor RF mapper).
%
% Each dot recycles two independent ways: crossing a DEPTH boundary
% (near boundary if moving forward, far boundary if moving backward --
% both are checked every frame so either self-motion direction works
% correctly), and an independent random LIFETIME countdown (respawns
% anywhere in the depth range). This dual mechanism is intentional --
% lifetime alone catches dots that would otherwise linger near the
% focus of expansion/contraction (where angular motion is slow even
% though depth motion isn't), which the depth-cycle alone would not
% reliably catch.
%
% SWITCHING DIRECTION: set the 'Self Motion Direction (binary)' table
% row in OpticFlow_master_360dots.m to 1 (forward) or -1 (backward).
% Forward dots approach and cross the near boundary, respawning far;
% backward dots recede and cross the far boundary, respawning near --
% both cases are handled below.
%
% Dots regenerate fresh at the start of every trial (not carried over),
% so trials are independent for downstream analysis. Trial duration and
% inter-trial gray interval both come from each trial's Timing field
% ([delay duration wait]), same convention as the RF mapper.
%
% Dot size follows a smooth, self-bounding falloff -- always strictly
% between Dot_Size_Min and Dot_Size_Max, no hard clamping/saturation --
% rather than an unbounded 1/r law that pins to Max for any close dot
% and decays toward Min everywhere else. Dot_Size_RefDepth (cm) is the
% distance PAST the near boundary (rMin) at which a dot's size has
% decayed halfway from Max to Min; smaller values = faster falloff
% (more dots look small), larger values = slower falloff (more dots
% look mid-sized/large).
%
% INPUT: TRIALS - structure array from trialStruct_RFmapFast for
%        stimType 'Optic Flow', built by OpticFlow_master_360dots.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

monitorInformation;

degPerPix      = monitorInfo.degPerPix; % assumes square angular pixels
screenSizeDegY = monitorInfo.screenSizeDegY;

% Dot-cloud configuration is constant across trials (see master script
% comments on extending Self_Motion_Direction to vary later); read it
% once from trial 1.
N          = trials(1).Num_Dots;
rMin       = trials(1).Depth_Min;
rMax       = trials(1).Depth_Max;
sizeMin    = trials(1).Dot_Size_Min;
sizeMax    = trials(1).Dot_Size_Max;
sizeRefZ   = trials(1).Dot_Size_RefDepth;
lifeMinSec = trials(1).Dot_Lifetime_Min;
lifeMaxSec = trials(1).Dot_Lifetime_Max;

elevMin = -screenSizeDegY/2;
elevMax =  screenSizeDegY/2;

Screen('Preference', 'Verbosity', 1);
Screen('Preference', 'VisualDebuglevel', 3);

try
    AssertOpenGL;

    screenNumber = monitorInfo.screenNumber;
    whitePix = WhiteIndex(screenNumber);
    blackPix = BlackIndex(screenNumber); %#ok<NASGU>
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
    dt         = waitframes * ifi; % physics timestep tied to measured ifi

    stimInitScreen(w, trials(1).Initialization_Screen, grayPix, ifi*waitframes);

    exitLoop = 0;
    nTrials  = numel(trials);

    for trial = 1:nTrials
        if exitLoop == 1
            break
        end

        delay    = trials(trial).Timing(1); %#ok<NASGU> % kept for parity/future use
        duration = trials(trial).Timing(2);
        waitSec  = trials(trial).Timing(3); % used as inter-trial gray interval

        selfMotionSpeed = trials(trial).Self_Motion_Speed * trials(trial).Self_Motion_Direction;

        if strcmp(trials(trial).Stimulus_Type, 'Blank')
            % Blank trial: skip dot simulation, just show the ITI gray
            % screen below.
        else
            %%%%%%%%%%%%%%%%%%%%%% SPAWN FRESH DOT CLOUD %%%%%%%%%%%%%%%%%%%
            [X, Y, Z] = localSpawnDots(N, rMin, rMax, elevMin, elevMax);
            lifetimeFrames = localRandomLifetimeFrames(N, lifeMinSec, lifeMaxSec, ifi);
            dotColorVal = localRandomDotColor(N, blackPix, whitePix);

            nFrames = round(duration / ifi);
            vbl = Screen('Flip', w);

            for f = 1:nFrames
                %%%%%%%%%%%%%%%%%%%%%% ADVANCE SELF-MOTION %%%%%%%%%%%%%%%%%
                Z = Z - selfMotionSpeed * dt;
                r = sqrt(X.^2 + Y.^2 + Z.^2);
                lifetimeFrames = lifetimeFrames - 1;

                %%%%%%%%%%%%%%%%%%% DEPTH-BOUNDARY RESPAWN %%%%%%%%%%%%%%%%%
                % Forward motion: dots approach and cross the NEAR
                % boundary, respawn far. Backward motion: dots recede and
                % cross the FAR boundary, respawn near. Both checked every
                % frame so flipping Self_Motion_Direction just works.
                idxNear = r < rMin;
                if any(idxNear)
                    nR = sum(idxNear);
                    [X(idxNear), Y(idxNear), Z(idxNear)] = ...
                        localSpawnDots(nR, rMax, rMax, elevMin, elevMax);
                    lifetimeFrames(idxNear) = ...
                        localRandomLifetimeFrames(nR, lifeMinSec, lifeMaxSec, ifi);
                    dotColorVal(idxNear) = localRandomDotColor(nR, blackPix, whitePix);
                end

                idxFar = r > rMax;
                if any(idxFar)
                    nF = sum(idxFar);
                    [X(idxFar), Y(idxFar), Z(idxFar)] = ...
                        localSpawnDots(nF, rMin, rMin, elevMin, elevMax);
                    lifetimeFrames(idxFar) = ...
                        localRandomLifetimeFrames(nF, lifeMinSec, lifeMaxSec, ifi);
                    dotColorVal(idxFar) = localRandomDotColor(nF, blackPix, whitePix);
                end

                idxBoundary = idxNear | idxFar;

                %%%%%%%%%%%%%%%%%%%%%% LIFETIME RESPAWN %%%%%%%%%%%%%%%%%%%%
                % Checked only on dots that didn't just respawn above.
                idxExpired = (lifetimeFrames <= 0) & ~idxBoundary;
                if any(idxExpired)
                    nL = sum(idxExpired);
                    [X(idxExpired), Y(idxExpired), Z(idxExpired)] = ...
                        localSpawnDots(nL, rMin, rMax, elevMin, elevMax);
                    lifetimeFrames(idxExpired) = ...
                        localRandomLifetimeFrames(nL, lifeMinSec, lifeMaxSec, ifi);
                    dotColorVal(idxExpired) = localRandomDotColor(nL, blackPix, whitePix);
                end

                %%%%%%%%%%%%%%%%%%%%%%%%%%% PROJECT %%%%%%%%%%%%%%%%%%%%%%%%
                r = sqrt(X.^2 + Y.^2 + Z.^2);
                azimuth   = mod(atan2d(X, Z), 360);
                elevation = atan2d(Y, sqrt(X.^2 + Z.^2));

                xPix = azimuth / degPerPix;
                yPix = (screenSizeDegY/2 - elevation) / degPerPix;

                radiusPix = sizeMin + (sizeMax - sizeMin) * sizeRefZ ./ (sizeRefZ + (r - rMin));

                dotRects = [xPix - radiusPix; yPix - radiusPix; ...
                            xPix + radiusPix; yPix + radiusPix];

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%% DRAW %%%%%%%%%%%%%%%%%%%%%%%%%
                Screen('FillRect', w, grayPix);
                Screen('FillOval', w, repmat(dotColorVal, 3, 1), dotRects);

                vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);

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
        itiFrames = round(waitSec / ifi);
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
function [X, Y, Z] = localSpawnDots(n, rLow, rHigh, elevMin, elevMax)
% Spawns n dots uniformly by VOLUME within the spherical shell
% [rLow, rHigh] (inverse-cube-CDF sampling, not naive uniform-in-r),
% azimuth uniform over the full 360deg, elevation uniform within the
% arena's displayable range. Pass rLow == rHigh for a fixed-depth spawn
% (used for depth-boundary respawns, which reappear at the far edge).

r = (rLow^3 + rand(1, n) * (rHigh^3 - rLow^3)) .^ (1/3);
azimuth0   = 360 * rand(1, n);
elevation0 = elevMin + (elevMax - elevMin) * rand(1, n);

Z = r .* cosd(elevation0) .* cosd(azimuth0);
X = r .* cosd(elevation0) .* sind(azimuth0);
Y = r .* sind(elevation0);
end

%% ------------------------------------------------------------------
function colorVal = localRandomDotColor(n, blackPix, whitePix)
% Assigns each of n dots a color independently at random: ~50% black,
% ~50% white. Called at initial spawn and again at every respawn (both
% depth-boundary and lifetime), so a dot's color is redrawn each time it
% reappears, same as its position and lifetime are.
isWhite = rand(1, n) < 0.5;
colorVal = blackPix * ones(1, n);
colorVal(isWhite) = whitePix;
end

%% ------------------------------------------------------------------
function frames = localRandomLifetimeFrames(n, lifeMinSec, lifeMaxSec, ifi)
% Draws n independent random lifetimes (frames), uniform between
% lifeMinSec and lifeMaxSec, converted using the measured flip interval.
lifeSec = lifeMinSec + (lifeMaxSec - lifeMinSec) * rand(1, n);
frames  = round(lifeSec / ifi);
end
