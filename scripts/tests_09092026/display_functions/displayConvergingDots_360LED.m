%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function displayConvergingDots_360LED(trials)
% CONVERGINGDOTS_360LED draws a random dot field on the 360deg LED arena
% -- same dot count / depth-shell / size-range spawning as
% displayStaticDots_360LED.m -- except every dot then moves in true 3D
% space toward a single fixed point in the virtual world (azimuth =
% 0deg, elevation = 0deg, depth = the midpoint of the dot-cloud's own
% depth shell, i.e. (Depth_Min+Depth_Max)/2 -- the middle of the
% virtual-world cylinder) and disappears permanently the instant it
% arrives.
%
% MOTION MODEL: dots move by straight-line linear interpolation of
% their actual 3D Cartesian position (X,Y,Z) toward the 3D target
% point, at a constant speed in cm/s -- NOT by interpolating azimuth
% and elevation directly. This is the geometrically correct version:
% because the interpolation happens in the same XYZ space the world is
% defined in, the projected path a dot traces on the arena is the true
% shortest path to the target (a "true 3D" convergence, curving
% correctly in azimuth/elevation as needed) with no separate azimuth
% wraparound logic required -- the 3D vector difference automatically
% takes the short way around.
%
% Each dot's distance to the target shrinks every frame; the instant
% that remaining distance is smaller than one frame's travel distance,
% the dot is retired (marked inactive) and no longer drawn for the rest
% of the trial. There is no respawn -- once a dot disappears at the
% convergence point it is gone for good, same as the RF-mapper/optic-
% flow convention of regenerating the whole cloud fresh only at the
% START of the next trial.
%
% Dot size (pixels, drawn once at spawn, no depth-dependent falloff)
% and color (~50% black / ~50% white, drawn once at spawn) work exactly
% as in displayStaticDots_360LED.m -- fixed per dot for the dot's whole
% lifetime, not re-randomized or resized while it moves (a dot's actual
% depth does change as it converges, but its on-screen SIZE does not --
% no looming effect is applied here).
%
% Dots regenerate fresh at the start of every trial (not carried over).
% Trial duration and inter-trial gray interval both come from each
% trial's Timing field ([delay duration wait]).
%
% INPUT: TRIALS - structure array from trialStruct_RFmapFast for
%        stimType 'Converging Dots' (or similar). Required per-trial /
%        constant fields (read once from trial 1, same convention as
%        the other 360LED display functions):
%           Num_Dots            - number of dots (e.g. 300)
%           Depth_Min           - inner shell radius, cm (spawn AND
%                                  used to derive the convergence
%                                  target's depth)
%           Depth_Max           - outer shell radius, cm (spawn AND
%                                  used to derive the convergence
%                                  target's depth)
%           Dot_Size_Min        - minimum dot diameter, pixels
%           Dot_Size_Max        - maximum dot diameter, pixels
%           Convergence_Speed   - speed of every dot toward the target
%                                  point, in cm/s (3D space, not deg/s)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

monitorInfo = getMonitorInformation();

degPerPix      = monitorInfo.degPerPix; % assumes square angular pixels
screenSizeDegY = monitorInfo.screenSizeDegY;

% Dot-cloud configuration is constant across trials; read it once from
% trial 1 (same convention as the other 360LED display functions).
N              = trials(1).Num_Dots;
rMin           = trials(1).Depth_Min;
rMax           = trials(1).Depth_Max;
sizeMin        = trials(1).Dot_Size_Min;
sizeMax        = trials(1).Dot_Size_Max;
convergeSpeed  = trials(1).Convergence_Speed; % cm/s, 3D space

elevMin = -screenSizeDegY/2;
elevMax =  screenSizeDegY/2;

% Convergence target: azimuth 0, elevation 0, depth = midpoint of the
% dot cloud's own depth shell (the middle of the virtual-world
% cylinder). In this pipeline's XYZ convention (Z = r*cos(el)*cos(az),
% X = r*cos(el)*sin(az), Y = r*sin(el)), az=0/el=0 collapses this to a
% single point straight down the Z axis.
targetDepth = (rMin + rMax) / 2;
Xt = 0;
Yt = 0;
Zt = targetDepth;

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

        if strcmp(trials(trial).Stimulus_Type, 'Blank')
            % Blank trial: skip dot field, just show the ITI gray screen
            % below.
        else
            %%%%%%%%%%%%%%%%%%%%%% SPAWN FRESH DOT CLOUD %%%%%%%%%%%%%%%%%%%
            [X, Y, Z] = localSpawnDots(N, rMin, rMax, elevMin, elevMax);
            radiusPix   = (sizeMin + (sizeMax - sizeMin) * rand(1, N)) / 2; % random size, bounded, in px radius
            dotColorVal = localRandomDotColor(N, blackPix, whitePix);

            active = true(1, N); % becomes false permanently once a dot arrives at the target

            nFrames = round(duration / ifi);
            vbl = Screen('Flip', w);

            for f = 1:nFrames
                %%%%%%%%%%%%%%%%%%%% ADVANCE TOWARD 3D TARGET %%%%%%%%%%%%%%
                dx = Xt - X;
                dy = Yt - Y;
                dz = Zt - Z;
                dist = sqrt(dx.^2 + dy.^2 + dz.^2);

                reached = active & (dist <= convergeSpeed * dt);
                moving  = active & ~reached;

                if any(moving)
                    frac = (convergeSpeed * dt) ./ dist(moving);
                    X(moving) = X(moving) + dx(moving) .* frac;
                    Y(moving) = Y(moving) + dy(moving) .* frac;
                    Z(moving) = Z(moving) + dz(moving) .* frac;
                end

                % Dots that reached the target this frame disappear now
                % (and stay gone -- no respawn).
                active(reached) = false;

                %%%%%%%%%%%%%%%%%%%%%%%%%%% PROJECT %%%%%%%%%%%%%%%%%%%%%%%%
                azimuth   = mod(atan2d(X, Z), 360);
                elevation = atan2d(Y, sqrt(X.^2 + Z.^2));

                xPix = azimuth / degPerPix;
                yPix = (screenSizeDegY/2 - elevation) / degPerPix;

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%% DRAW %%%%%%%%%%%%%%%%%%%%%%%%%
                Screen('FillRect', w, grayPix);
                if any(active)
                    dotRects = [xPix(active) - radiusPix(active); ...
                                yPix(active) - radiusPix(active); ...
                                xPix(active) + radiusPix(active); ...
                                yPix(active) + radiusPix(active)];
                    Screen('FillOval', w, repmat(dotColorVal(active), 3, 1), dotRects);
                end

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
% arena's displayable range. Identical sampling to the other 360LED
% display functions.

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
% ~50% white. Called once per trial at spawn (fixed per dot for its
% whole lifetime, not re-randomized while it moves).
isWhite = rand(1, n) < 0.5;
colorVal = blackPix * ones(1, n);
colorVal(isWhite) = whitePix;
end
