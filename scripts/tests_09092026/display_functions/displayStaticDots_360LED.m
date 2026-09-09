%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function displayStaticDots_360LED(trials)
% STATICDOTS_360LED draws a static (non-moving) random dot field on the
% 360deg LED arena, one trial at a time from the TRIALS struct built by
% trialStruct_RFmapFast (same pipeline/conventions as
% displayOpticFlow_360LED.m and ReceptiveFieldMapping_Fast_polar.m, just
% a much simpler stimulus -- no self-motion, no depth-boundary respawn,
% no lifetime countdown).
%
% Each dot has a fixed 3D position (X,Y,Z) relative to the mouse in a
% virtual world, sampled once per trial uniformly BY VOLUME within a
% spherical shell of inner radius Depth_Min and outer radius Depth_Max
% (e.g. 2*R_arena to 3*R_arena). The dot never moves during the trial --
% it is projected once to arena azimuth/elevation via spherical
% coordinates (the arena IS the angular coordinate system, same as the
% optic-flow display) and just held there, redrawn every flip, for the
% full trial duration.
%
% Each dot gets, independently at spawn:
%   - a random size in PIXELS, drawn uniformly between Dot_Size_Min and
%     Dot_Size_Max (no depth-dependent falloff -- size is just random,
%     not distance-scaled, since nothing is moving in depth)
%   - a random color, ~50% black / ~50% white
%
% Dots regenerate fresh at the start of every trial (not carried over),
% so trials are independent for downstream analysis, same convention as
% the RF mapper and the optic-flow display. Trial duration and
% inter-trial gray interval both come from each trial's Timing field
% ([delay duration wait]).
%
% INPUT: TRIALS - structure array from trialStruct_RFmapFast for
%        stimType 'Static Dots' (or similar), built by a master script
%        analogous to OpticFlow_master_360dots.m. Required per-trial /
%        constant fields (read once from trial 1, same convention as
%        the optic-flow display):
%           Num_Dots        - number of dots (e.g. 300)
%           Depth_Min       - inner shell radius, cm (e.g. 2*R_arena)
%           Depth_Max       - outer shell radius, cm (e.g. 3*R_arena)
%           Dot_Size_Min    - minimum dot diameter, pixels
%           Dot_Size_Max    - maximum dot diameter, pixels
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

monitorInfo = getMonitorInformation();

degPerPix      = monitorInfo.degPerPix; % assumes square angular pixels
screenSizeDegY = monitorInfo.screenSizeDegY;

% Dot-cloud configuration is constant across trials; read it once from
% trial 1 (same convention as displayOpticFlow_360LED.m).
N       = trials(1).Num_Dots;
rMin    = trials(1).Depth_Min;
rMax    = trials(1).Depth_Max;
sizeMin = trials(1).Dot_Size_Min;
sizeMax = trials(1).Dot_Size_Max;

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

            %%%%%%%%%%%%%%%%%%%%%%%%%%% PROJECT (ONCE) %%%%%%%%%%%%%%%%%%%%%
            % Dots are static, so azimuth/elevation/size/color never
            % change within the trial -- computed once, held for every
            % frame of the trial's duration.
            azimuth   = mod(atan2d(X, Z), 360);
            elevation = atan2d(Y, sqrt(X.^2 + Z.^2));

            xPix = azimuth / degPerPix;
            yPix = (screenSizeDegY/2 - elevation) / degPerPix;

            dotRects = [xPix - radiusPix; yPix - radiusPix; ...
                        xPix + radiusPix; yPix + radiusPix];

            nFrames = round(duration / ifi);
            vbl = Screen('Flip', w);

            for f = 1:nFrames
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
% arena's displayable range. Identical sampling to
% displayOpticFlow_360LED.m's localSpawnDots.

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
% ~50% white. Called once per trial at spawn (dots are static, so color
% is not redrawn mid-trial).
isWhite = rand(1, n) < 0.5;
colorVal = blackPix * ones(1, n);
colorVal(isWhite) = whitePix;
end
