%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function displayConvergingDotsLoop_360LED(trials)
% DISPLAYCONVERGINGDOTSLOOP_360LED draws a random dot field on the 360deg
% LED arena -- same dot count / depth-shell / size-range spawning as
% displayStaticDots_360LED.m -- except every dot moves in true 3D space
% toward a single fixed point (azimuth = 0deg, elevation = 0deg, depth =
% the midpoint of the dot-cloud's own depth shell, i.e.
% (Depth_Min+Depth_Max)/2) and, instead of disappearing permanently on
% arrival (as in displayConvergingDots_360LED.m), IMMEDIATELY
% reappears at the antipodal point on the arena -- azimuth flipped by
% 180deg and elevation mirrored (negated) -- at a freshly-sampled depth
% within the same shell, and resumes converging toward the same target.
% Because the teleport happens the instant a dot would have arrived
% (same frame, no frame spent sitting at the vanishing point), there is
% no visible pop/flicker pileup at the convergence point -- the flow
% looks like a continuous, seamless loop of dots streaming in from all
% directions.
%
% Why "azimuth+180, elevation negated" is the "opposite end of the
% arena": the convergence target has X=Y=0 (it sits on the az=0/el=0
% axis), so the antipodal point on the spherical shell relative to the
% viewer's origin is the standard sphere-antipode formula (lon+180,
% -lat). Since elevation is sampled from a symmetric range
% (elevMin = -screenSizeDegY/2, elevMax = +screenSizeDegY/2), negating
% elevation always stays within the displayable range.
%
% Every dot therefore lives forever for the duration of the trial,
% perpetually flying from some point on the shell to the center and
% immediately re-emerging from the opposite point on the shell. There
% is no permanent retirement and no "active" mask -- all N dots are
% drawn every frame.
%
% CONTINUITY: two things keep the flow from looking like a synchronized
% "everyone converges, everyone resets" pulse instead of a continuous
% stream. (1) WARM-UP: before any frame is drawn, the same advance/
% respawn physics is silently run for several worst-case round-trips'
% worth of frames, so by the time the trial is actually visible the
% population has already cycled through multiple staggered arrivals --
% you start already in steady-state flow, not at a synchronized frame
% one. (2) JITTER: each antipodal respawn adds a small random offset
% (JITTER_DEG below) to the exact az+180/-el antipode, so a dot never
% settles into a perfectly repeating 2-position loop that could
% re-synchronize with other dots over a long trial.
%
% FRONT/BACK DENSITY: dots travel at constant PHYSICAL speed (cm/s),
% but the target is a single fixed bearing (az0/el0). As any
% straight-line path gets close to that point, its physical distance
% keeps shrinking steadily while its ON-SCREEN bearing has almost
% nowhere left to go but straight at az0/el0 -- so every dot's angular
% velocity slows sharply right before arrival, and it lingers near the
% front for a disproportionate share of its travel time versus the
% brief moment it spends near its far/back reappearance point. This is
% geometric, not a bug. ARRIVAL_RADIUS (below) counteracts it: instead
% of requiring a dot to travel all the way to (within one frame-step
% of) the exact target, a dot counts as "arrived" -- and loops to the
% antipode -- once it gets within ARRIVAL_RADIUS cm of the target.
% Cutting the trajectory off before it enters the slow-angular-velocity
% zone near the sink reduces the front-side pileup and lets density
% look more even across the arena; too large a value will make the
% convergence look like it's collapsing into a small hub rather than a
% sharp point, so tune to taste.
%
% Dot size (pixels, drawn once at spawn, no depth-dependent falloff)
% and color (~50% black / ~50% white, drawn once at spawn) work exactly
% as in displayStaticDots_360LED.m / displayConvergingDots_360LED.m --
% fixed per dot for the dot's whole trial lifetime, not re-randomized
% or resized on each loop-through (a dot's actual depth does change as
% it converges and resets, but its on-screen SIZE/color do not).
%
% Dots regenerate fresh at the start of every trial (not carried over
% between trials). Trial duration and inter-trial gray interval both
% come from each trial's Timing field ([delay duration wait]).
%
% INPUT: TRIALS - structure array from trialStruct_RFmapFast for
%        stimType 'Converging Dots Loop' (or similar). Required
%        per-trial / constant fields (read once from trial 1, same
%        convention as the other 360LED display functions):
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
%           Arrival_Radius      - distance (cm) from the target within
%                                  which a dot counts as "arrived" and
%                                  loops to the antipode (see FRONT/BACK
%                                  DENSITY note above -- larger values
%                                  reduce front-crowding at the cost of
%                                  a less pinpoint convergence)
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
arrivalRadius0 = trials(1).Arrival_Radius; % cm, from the table now -- see FRONT/BACK DENSITY note above

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

JITTER_DEG = 15; % random spread applied to each antipodal respawn, deg (see CONTINUITY note above)
ARRIVAL_RADIUS = arrivalRadius0; % cm; from trials(1).Arrival_Radius -- see FRONT/BACK DENSITY note above

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
            [X, Y, Z, anchorAz, anchorEl] = localSpawnDots(N, rMin, rMax, elevMin, elevMax);
            radiusPix   = (sizeMin + (sizeMax - sizeMin) * rand(1, N)) / 2; % random size, bounded, in px radius
            dotColorVal = localRandomDotColor(N, blackPix, whitePix);

            step = convergeSpeed * dt; % distance covered by every dot per frame

            %%%%%%%%%%%%%%%%%%%%%% WARM-UP (NOT DRAWN) %%%%%%%%%%%%%%%%%%%%%
            % Silently run the same advance/respawn physics for several
            % worst-case round-trips before the trial is ever displayed,
            % so the population starts the visible trial already
            % mid-flow instead of all spawning together at frame 1 (see
            % CONTINUITY note above).
            worstCaseDist = rMax + targetDepth; % farthest any dot could start from the target
            warmupSeconds = 3 * worstCaseDist / convergeSpeed;
            warmupFrames  = ceil(warmupSeconds / dt);
            for wf = 1:warmupFrames
                [X, Y, Z, anchorAz, anchorEl] = localAdvanceAndRespawn( ...
                    X, Y, Z, anchorAz, anchorEl, Xt, Yt, Zt, step, rMin, rMax, ...
                    elevMin, elevMax, JITTER_DEG, ARRIVAL_RADIUS);
            end

            nFrames = round(duration / ifi);
            vbl = Screen('Flip', w);

            for f = 1:nFrames
                %%%%%%%%%%%%%% ADVANCE TOWARD TARGET + LOOP AT ANTIPODE %%%%
                [X, Y, Z, anchorAz, anchorEl] = localAdvanceAndRespawn( ...
                    X, Y, Z, anchorAz, anchorEl, Xt, Yt, Zt, step, rMin, rMax, ...
                    elevMin, elevMax, JITTER_DEG, ARRIVAL_RADIUS);

                %%%%%%%%%%%%%%%%%%%%%%%%%%% PROJECT %%%%%%%%%%%%%%%%%%%%%%%%
                azimuth   = mod(atan2d(X, Z), 360);
                elevation = atan2d(Y, sqrt(X.^2 + Z.^2));

                xPix = azimuth / degPerPix;
                yPix = (screenSizeDegY/2 - elevation) / degPerPix;

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%% DRAW %%%%%%%%%%%%%%%%%%%%%%%%%
                % All N dots are drawn every frame -- nothing is ever
                % permanently inactive in the looping version.
                Screen('FillRect', w, grayPix);
                dotRects = [xPix - radiusPix; ...
                            yPix - radiusPix; ...
                            xPix + radiusPix; ...
                            yPix + radiusPix];
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
function [X, Y, Z, anchorAz, anchorEl] = localAdvanceAndRespawn( ...
    X, Y, Z, anchorAz, anchorEl, Xt, Yt, Zt, step, rMin, rMax, elevMin, elevMax, jitterDeg, arrivalRadius)
% One physics tick shared by both the silent warm-up and the visible
% per-frame loop: advance every dot toward the target by STEP (3D cm),
% then any dot within ARRIVAL_RADIUS of the target (not just one frame-
% step away -- see FRONT/BACK DENSITY note above) instead teleports to
% the antipodal point on the shell (azimuth+180, elevation negated)
% plus a small random JITTER_DEG offset, at a freshly sampled depth --
% and keeps converging. No dot is ever permanently retired.

dx = Xt - X;
dy = Yt - Y;
dz = Zt - Z;
dist = sqrt(dx.^2 + dy.^2 + dz.^2);

arriveThresh = max(step, arrivalRadius); % never smaller than one frame's travel, or dots could stall just outside it
reached = dist <= arriveThresh;
moving  = ~reached;

if any(moving)
    frac = step ./ dist(moving);
    X(moving) = X(moving) + dx(moving) .* frac;
    Y(moving) = Y(moving) + dy(moving) .* frac;
    Z(moving) = Z(moving) + dz(moving) .* frac;
end

if any(reached)
    idx = find(reached);
    nR = numel(idx);

    anchorAz(idx) = mod(anchorAz(idx) + 180 + jitterDeg * (2*rand(1, nR) - 1), 360);
    anchorEl(idx) = -anchorEl(idx) + jitterDeg * (2*rand(1, nR) - 1);
    anchorEl(idx) = min(max(anchorEl(idx), elevMin), elevMax); % clamp jitter to displayable range

    newR = (rMin^3 + rand(1, nR) * (rMax^3 - rMin^3)) .^ (1/3);
    Z(idx) = newR .* cosd(anchorEl(idx)) .* cosd(anchorAz(idx));
    X(idx) = newR .* cosd(anchorEl(idx)) .* sind(anchorAz(idx));
    Y(idx) = newR .* sind(anchorEl(idx));
end
end

%% ------------------------------------------------------------------
function [X, Y, Z, azimuth0, elevation0] = localSpawnDots(n, rLow, rHigh, elevMin, elevMax)
% Spawns n dots uniformly by VOLUME within the spherical shell
% [rLow, rHigh] (inverse-cube-CDF sampling, not naive uniform-in-r),
% azimuth uniform over the full 360deg, elevation uniform within the
% arena's displayable range. Identical sampling to the other 360LED
% display functions. Also returns each dot's spawn azimuth/elevation
% so the caller can use them as a rotating "anchor" angle across
% repeated loop-throughs (flipped to the antipodal point each time a
% dot reaches the convergence target).

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
% whole lifetime, not re-randomized while it moves or loops).
isWhite = rand(1, n) < 0.5;
colorVal = blackPix * ones(1, n);
colorVal(isWhite) = whitePix;
end
