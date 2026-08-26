%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%copyright (c) 2012  Matthew Caudill
%
%this program is free software: you can redistribute it and/or modify
%it under the terms of the gnu general public license as published by
%the free software foundation, either version 3 of the license, or
%at your option) any later version.

%this program is distributed in the hope that it will be useful,
%but without any warranty; without even the implied warranty of
%merchantability or fitness for a particular purpose.  see the
%gnu general public license for more details.

%you should have received a copy of the gnu general public license
%along with this program.  if not, see <http://www.gnu.org/licenses/>.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Old no-output signature kept for reference.
% Reason for comment-out: keep the output signature used by rotation entry
% points while returning the original RF-map trial log.
% function ReceptiveFieldMapping_Fast_360degLED_Rotate(trials)
function trials = ReceptiveFieldMapping_Fast_360degLED_Rotate(trials)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %This function generates black or white square sequences with parameters
    %defined by the array of trials structures (see trialStruct.m). Trials
    %structures are automatically generated from the table values in the gui
    %by trialsStruct.m so your stimulus should take only one input namely
    %trials. You can access parameters of a structure in the trials structure
    %array using dynamic field referencing (e.g. trials(1).Orientation ...
    %returns the orientaiton of trial 1). As you write your stimulus you can
    %test it by creating a Default trials structure as done below so you can
    %see if it is behaving as expected before adding it to the stimGen gui.
    %
    % INPUTS:  TRIALSSTRUCT
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Written by MSC 4-23-12 (Modified from DriftDemo2 in PTB)
    % Modified by: MSC/2012-4-27,
    % Modifid by: YS 2018-03-23,
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%%%%%%%%%%%%%%%%%%%%% DEFAULTS FOR TESTING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %UNCOMMENT THIS SECTION FOR RUNNING STIMULUS AS STAND ALONE; COMMENT ABOVE
    %CONFLICTING FUNCTION FULLFIELDGRATING(TRIALS)
    % function [trials] = FullFieldGrating(stimType,table)
    % if nargin<1
    %     table = {'Square Size (deg)', 5, 1, 5;...
    %               'Square PositionX (deg)', -22.5, 5, 22.5;...
    %               'Square PositionY (deg)', -22.5, 5, 22.5;...
    %               'Square Luminance (binary)', 0, 1, 1;...
    %               'Timing (delay,duration,wait) (s)', 0.1, 0.1, 0.1;...
    %               'Blank', 0, [], [];
    %               'Randomize', 1, [], [];...
    %               'Interleave', 0, [], [];...
    %               'Repeats', 1, [], [];...
    %               'Initialization Screen (s)', 5, [],[]};
    %    stimType = 'Receptive Field Mapping';
    %
    % end
    % trials = trialStruct_RFmapS_Yuta(stimType, table);

    %%%%%USE WITH CAUTION%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Screen('Preference', 'SkipSyncTests', 1);%% better to be commented
    %%Screen('Preference', 'SkipSyncTests', 0);%% use this after above
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Get monitor info from monitorInformation located in RigSpecificInfo dir.
    % This structure contains all the pertinent monitor information we will
    % need such as screen size and appropriate conversions from pixels to
    % visual degrees
    monitorInformation;
    %
    % amp=10 ;
    % fs=48000 ; % sampling frequency
    % duration=0.1;
    % freq=10000;
    % values=0:1/fs:duration;
    % a=amp*sin(2*pi* freq*values);

    %%%%%%%%%%%%%%%%%%%%% TURN OFF PTB SYSTEM CHECK REPORT %%%%%%%%%%%%%%%%%%%%
    Screen('Preference', 'Verbosity', 1);
    % This will suppress all but critical warning messages
    % At the end of the code we will return the verbosity back to norm level 3

    % please see the following page for an explanation of this function
    % http://psychtoolbox.org/FaqWarningPrefs
    % NOTE: as you debug your code comment this line because PTB will return
    % back useful info about memory usage that will tell you about leaks that
    % may casue problems

    % When Screen('OpenWindow',w,color) is called, PTB performs many checks of
    % your system. The time it takes to perform these checks depends on the
    % noisiness of your system (up to two seconds on 2-photon rig). During this
    % time it displays a white screen which is obviously not good for visual
    % stimulation. We can disable the startup screen using the following. The
    % sreen will now be black before visual stimulus
    Screen('Preference', 'VisualDebuglevel', 3);
    % see http://psychtoolbox.org/FaqBlueScreen for a reference

    %%%%%%%%%%%%%%%%%%%%% OPEN A SCREEN & DETERMINE PARAMETERS %%%%%%%%%%%%%%%%
    % Use a try except block to prevent the screen from hanging. During testing
    % if the screen does hang press cntrl C or cntrl-alt del to bring up the
    % task manager to stop PTB execution
    try

        % Require OPENGL becasue some of the functions used here need the
        % OPENGL version of PTB
        AssertOpenGL;

        %%%%%%%%%%%%%%%%%%%%%% GET SPECIFIC MONITOR INFORMATION %%%%%%%%%%%%%%%%%%%

        % SCREEN WE WILL DISPLAY ON
        %Query monitorInformation for screenNumber
        screenNumber = monitorInfo.screenNumber;

        % COLOR INFORMATION OF SCREEN
        % Get black, white and gray color values for the current monitor
        whitePix = WhiteIndex(screenNumber);
        blackPix = BlackIndex(screenNumber);

        %Convert balck and white to luminance values to determine gray
        %luminance
        whiteLum = PixToLum(whitePix);
        blackLum = PixToLum(blackPix);
        grayLum = (whiteLum + blackLum) * 0.33;

        % Now determine the pixel value of gray from the gray luminance

        % grayPix = GammaCorrect(grayLum);
        grayPix = grayLum;

        backgroundColor = grayPix;
        % backgroundColor = [90 120 90]; % MAKE IT GREEN

        % CONVERSION FROM DEGS TO PX AND SIZING INFO FOR SCREEN
        %conversion factor specific to monitor
        degPerPix = monitorInfo.degPerPix;

        RightBoxBG = grayPix;
        % RightBoxBG = backgroundColor; % MAKE IT GREEN

        LeftBoxBG = grayPix;
        % LeftBoxBG = backgroundColor; % MAKE IT GREEN

        %%%%%%%%%%%%%%%%%%%%%%%%%% INITIAL SCREEN DRAW %%%%%%%%%%%%%%%%%%%%%%%%%%%
        % We start with a gray screen before generating our stimulus and displaying
        % our stimulus.

        % Old cursor hiding kept for reference.
        % Reason for comment-out: leave the cursor visible during this rotate test.
        % HideCursor;
        % OPEN A SCREEN WITH A BG COLOR OF BLACK (RETURN POINTER W)
        [w, screenRect] = Screen('OpenWindow', screenNumber, blackPix);
        % [w, screenRect] = Screen('OpenWindow', screenNumber, backgroundColor); % MAKE IT GREEN

        LeftBoxStim_small(w, screenRect, LeftBoxBG); % MAKE IT GREEN

        %%%%%%%%%%%%%%%%%%%%%%%%% PREP SCREEN FOR DRAWING %%%%%%%%%%%%%%%%%%%%%%%%%

        % SCRIPT PRIORITY LEVEL
        % Query for the maximum priority level availbale on this system. This
        % determines the priority level of the matlab thread (0= normal,
        % 1=high, 2=realTime priority) note that a setting of 2 may cause the
        % keyboard to be unresponsive. You may want to play with this number if
        % you have trouble recovering the screen back

        priorityLevel = MaxPriority(w);
        Priority(priorityLevel);

        % INTERFRAME INTERVAL INFO
        % Get the montior inter-frame-interval
        ifi = Screen('GetFlipInterval', w);

        %on old slow machines we may not be able to update every ifi. If your
        %graphics processor is too slow you can buy a better one or adjust the
        %number of frames to wait between flips below

        waitframes = 1; %I expect most new computers can handle updates at ifi
        ifiDuration = waitframes * ifi;
        %
        % % CREATE A DESTINATION RECTANGLE where the stimulus will be drawn to
        %     dstRect=[0 0 monitorInfo.screenSizePixX monitorInfo.screenSizePixY];
        %     %center the rectangle to the screen
        %     dstRect=CenterRect(dstRect, screenRect);

        %%%%%%%%%%%%%%%%%%%%%% DRAW PRESTIM GRAY SCREEN %%%%%%%%%%%%%%%%%%%%%%%%%%%
        % We call the function stimInitScreen to draw a screen to the window before
        % the stimulus appears to allow for any adaptation that is need to a change
        % in luminance
        stimInitScreen(w, trials(1).Initialization_Screen, blackPix, ifiDuration)
        % stimInitScreen(w, trials(1).Initialization_Screen, backgroundColor, ifiDuration); % MAKE IT GREEN

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%% CONSTRUCT AND DRAW TEXTURES %%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % This is the main body of the code. We will loop through our trials array
        % structure, construct a grating texture based on the values for each trial
        % and then execute the drawing in a while loop. All of this must be done in
        % a single loop becasue we need to close the textures in the trial loop
        % after using each texture becasue otherwise they will hang around in
        % memory and cause the familiar Java runtime error: Out of memory.

        % Exit Codes and initialization

        % This is a flag indicating we need to break from the trials
        % structure loop below. The flag becomes true (=1) if the
        % user presses any key
        exitLoop = 0;

        % Build one horizontally wrapped cylindrical background texture.
        W = monitorInfo.screenSizePixX;
        H = monitorInfo.screenSizePixY;

        baseMtrx = blackPix * ones(H, W);
        [xGrid, yGrid] = meshgrid(1:W, 1:H);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Pattern 1
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % circleX = round(0.20 * W);
        % circleY = round((1 - 0.75) * H);
        % circleR = round(0.04 * W);

        % barW = round(0.02 * W);
        % barCenters = round([0.35 0.50 0.85] * W);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Pattern 2
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        circleX = round(0.42 * W);
        circleY = round((1 - 0.75) * H);  % keep same vertical position
        circleR = round(0.04 * W);
        
        

        barW = round(0.02 * W);
        barCenters = round([0.06 0.18 0.72 0.87] * W);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        circleMask = (xGrid - circleX).^2 + (yGrid - circleY).^2 <= circleR.^2;
        baseMtrx(circleMask) = grayPix;


        for barIdx = 1:numel(barCenters)
            x1 = (barCenters(barIdx) - barW / 2) + 1;
            x2 = x1 + barW - 1;
            baseMtrx(:, x1:x2) = grayPix;
        end

        movingTex = Screen('MakeTexture', w, [baseMtrx baseMtrx]);
        % Old wall-clock motion state kept for reference.
        % Reason for comment-out: the RF grid should advance once per
        % non-blank trial, not continuously based on elapsed time.
        % motionStart = [];
        motionStep = 0;
        stimulusStarted = false;

        % MAIN LOOP OVER TRIALS TO DRAW THE FOREGROUND STIMULUS OVER THE BACKGROUND
        for trial = 1:numel(trials)

            if exitLoop == 1;
                break;
            end

            n = 0; % This is a counter to shift our grating on each redraw

            %%%%%%%%%%%%%%%%%%%% GET STIMULUS TIMING INFORMATION %%%%%%%%%%%%%%%%%%%%%%
            % The wait, duration, and delay are stored in trials structure. They
            % may vary over the trials if an LED was shown so get them for each
            % trial
            delay = trials(trial).Timing(1);
            duration = trials(trial).Timing(2);
            wait = trials(trial).Timing(3);

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%% CONSTRUCT STIMULUS TEXTURES %%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % To make a static grating texture of a drifting grating we need the
            % contrast and the spatial frequency. For each trial in our structure we
            % will get these two variables and convert them to appropraite units and
            % then make our texture.

            % Get the contrast and spatial frequency of the trial
            flagLuminance = trials(trial).Square_Luminance;
            degPositionX = trials(trial).Square_PositionX;
            degPositionY = trials(trial).Square_PositionY;
            degSize = trials(trial).Square_Size;

            % Old luminance-driven square color kept for reference.
            % Reason for comment-out: rotate RF squares should be white only.
            % if flagLuminance == 0
            %     SquareLum = blackPix;
            %     % SquareLum = repmat(blackPix, 1, 3); % MAKE IT GREEN
            % elseif flagLuminance == 1
            %     SquareLum = whitePix;
            %     % SquareLum = repmat(whitePix, 1, 3); % MAKE IT GREEN
            % end
            SquareLum = whitePix;

            % convert to pixel units
            pxSize = ceil(degSize / degPerPix);
            pxPositionX = ceil(degPositionX / degPerPix);
            pxPositionY = ceil(degPositionY / degPerPix);
            pxHalfSize = ceil(pxSize / 2);

            % compute square pixXlim and pixYlim in pix
            pixXlim(1) = ceil(monitorInfo.screenSizePixX / 2) + pxPositionX - pxHalfSize;
            pixXlim(2) = pixXlim(1) + pxSize;
            pixYlim(1) = ceil(monitorInfo.screenSizePixY / 2) + pxPositionY - pxHalfSize;
            pixYlim(2) = pixYlim(1) + pxSize;
            squareRect = [pixXlim(1) - 1 pixYlim(1) - 1 pixXlim(2) pixYlim(2)];

            % Old full-screen square texture path kept for reference.
            % Reason for comment-out: the gray pixels in this texture are opaque
            % and would cover the moving background layer. The active code below
            % draws only the square rectangle over the moving background instead.
            % imMtrx = grayPix * ones(monitorInfo.screenSizePixY, monitorInfo.screenSizePixX);
            % % imMtrx = repmat(reshape(backgroundColor, 1, 1, 3), monitorInfo.screenSizePixY, monitorInfo.screenSizePixX); % MAKE IT GREEN
            %
            % for i = 1:monitorInfo.screenSizePixX
            %
            %     for j = 1:monitorInfo.screenSizePixY
            %
            %         if i >= pixXlim(1) && i <= pixXlim(2) ...
            %                 && j >= pixYlim(1) && j <= pixYlim(2)
            %
            %             imMtrx(j, i) = SquareLum;
            %             % imMtrx(j, i, :) = SquareLum; % MAKE IT GREEN
            %         end
            %
            %     end
            %
            % end
            %
            % squaretex{trial} = Screen('MakeTexture', w, imMtrx);

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DRAW TEXTURES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % In DRAW TEXTURES, we will obtain specific parameters such as the
            % orientation etc for each trial in the trials struct. We will then draw an
            % initial gray screen persisting for a time called delay. Then we will draw
            % our grating using the parameters we pulled from the trials structure.
            % Lastly we will draw another gray screen persisting for a time called
            % wait. We repeat until the end of trials.

            %%%%%%%%%%%%%%%%%%%% DRAW DELAY GRAY SCREEN %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %     % DEVELOPER NOTE: Prior versions of stimuli used the func WaitSecs to
            %     % draw gray screens. This is a bad practice because the function sleeps
            %     % the matlab thread making the computer unresponsive to KbCheck clicks.
            %     % In addition PTB only guarantees the accuracy of WaitSecs to the
            %     % millisecond scale whereas VBL timestamps described below uses
            %     % GetSecs() a highly accurate submillisecond estimate of the system
            %     % time. All times should be referenced to this estimate for better
            %     % accuracy.
            %
            %     % We start by performing an initial screen flip using Screen, we return
            %     % back a time called vbl. This value is a high precision time estimate
            %     % of when the graphics card performed a buffer swap. This time is what
            %     % all of our times will be referenced to. More details at
            %     % http://psychtoolbox.org/FaqFlipTimestamps
            %         vbl=Screen('Flip', w);
            %         LeftBoxStim(w, screenRect, LeftBoxBG);
            %         RightBoxStim(w, screenRect, RightBoxBG);
            %     % The first time element of the stimulus is the delay from trigger
            %     % onset to stimulus onset
            %         delayTime = vbl + delay;
            %
            %     % Display a gray screen while the vbl is less than delay time. NOTE
            %     % we are going to add 0.5*ifi to the vbl to give us some headroom
            %     % to take possible timing jitter or roundoff-errors into account.
            %         while (vbl < delayTime)
            %             % Draw a gray screen
            %             Screen('FillRect', w,grayPix);
            %             LeftBoxStim(w, screenRect, LeftBoxBG);
            %             RightBoxStim(w, screenRect, RightBoxBG);
            %
            %             % update the vbl timestamp and provide headroom for jitters
            %             vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);
            %
            %             % exit the while loop and flag to one if user presses any key
            %             if KbCheck
            %                 exitLoop=1;
            %                 break;
            %             end
            %         end
            %
            %%%%%%%%%%%%%%%%%%%%%%%%% DRAW LAYERED STIMULUS %%%%%%%%%%%%%%%%%%%%%%%%%%%
            % If the trial is a blank then we do not need to set src and dst
            % rect and calculate texture shifts etc
            if ~strcmp(trials(trial).Stimulus_Type, 'Blank')

                % Old first-trial condition kept for reference.
                % Reason for comment-out: the moving layer timing should start
                % on the first non-blank draw, even if earlier trials are blank.
                % if trial == 1
                %
                %     vbl = Screen('Flip', w);
                % end
                if ~stimulusStarted
                    vbl = Screen('Flip', w);
                    stimulusStarted = true;
                end

                trialMotionStep = mod(floor(motionStep / 2), W);
                xoffset = mod(W - trialMotionStep, W);
                srcRect = [xoffset 0 xoffset + W H];

                % Set the runtime of each trial by adding duration to vbl time
                runtime = vbl + duration;

                while (vbl < runtime)
                    % Draw the moving background first, then the static RF square.
                    Screen('DrawTextures', w, movingTex, srcRect, screenRect);
                    Screen('FillRect', w, SquareLum, squareRect);

                    % Draw a box at the bottom right of the screen to record
                    % all screen flips using a photodiode. Please see the file
                    % FlipCheck.m in the stimulus directory for further
                    % explanation
                    if mod(trial, 2) == 1
                        LeftBoxStim_small(w, screenRect, blackPix);
                    else
                        LeftBoxStim_small(w, screenRect, whitePix);
                    end

                    % update the vbl timestamp and provide headroom for jitters
                    vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);
                    % vbl=Screen('Flip', w);
                    %                time = time + ifi;

                    % exit the while loop and flag to one if user presses any
                    % key
                    if KbCheck
                        exitLoop = 1;
                        break;
                    end

                end

                motionStep = motionStep + 1;

            end

            %%%%%%%%%%%%%%%%%%%%% DRAW INTERSTIMULUS GRAY SCREEN %%%%%%%%%%%%%%%%%%%%%%
            %         % Between trials we want to draw a gray screen for a time of wait
            %
            %         % Flip the screen and collect the time of the flip
            %         vbl=Screen('Flip', w);
            %         LeftBoxStim(w, screenRect, LeftBoxBG);
            %         RightBoxStim(w, screenRect, RightBoxBG);
            %         %sound(a,fs,24);
            %         % We will loop until delay time referenced to the flip time
            %         waitTime = vbl + wait;
            %         %
            %         while (vbl < waitTime)
            %             % Draw a gray screen
            %             Screen('FillRect', w,grayPix);
            %             LeftBoxStim(w, screenRect, LeftBoxBG);
            %             RightBoxStim(w, screenRect, RightBoxBG);
            %
            %             % update the vbl timestamp and provide headroom for jitters
            %             vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);
            %
            %             % exit the while loop and flag to one if user presses any key
            %             if KbCheck
            %                 exitLoop=1;
            %                 break;
            %             end
            %         end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % movingTex is reused across trials and closed after the trial loop.
            % Old per-trial close kept for reference.
            % Reason for comment-out: squaretex is not allocated in the active
            % layered path; movingTex is the only Psychtoolbox texture added here.
            % Screen('Close', squaretex{trial})
        end

        % Old early-exit squaretex cleanup kept for reference.
        % Reason for comment-out: squaretex is not allocated in the active
        % layered path, so closing it would reference a non-existent texture.
        % if exitLoop
        %
        %     try
        %         Screen('Close', squaretex{trial})
        %     catch
        %     end
        %
        % end
        Screen('Close', movingTex)

        %%%% blank screen after exp %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Flip the screen and collect the time of the flip
        vbl = Screen('Flip', w);
        LeftBoxStim_small(w, screenRect, LeftBoxBG);

        % We will loop until delay time referenced to the flip time
        waitTime = vbl + 2; % wait 2 [sec]
        %
        while (vbl < waitTime)
            % Draw a gray screen
            Screen('FillRect', w, grayPix);
            % Screen('FillRect', w, backgroundColor); % MAKE IT GREEN

            LeftBoxStim_small(w, screenRect, LeftBoxBG);

            % update the vbl timestamp and provide headroom for jitters
            vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);

            %         % exit the while loop and flag to one if user presses any key
            %         if KbCheck
            %             exitLoop=1;
            %             break;
            %         end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % Restore normal priority scheduling in case something else was set
        % before:
        Priority(0);

        %The same commands wich close onscreen and offscreen windows also close
        %textures. We still need to close any screens opened prior to the trial
        %loop ( the prep screen for example)
        Screen('CloseAll');

    catch
        %this "catch" section executes in case of an error in the "try" section
        %above.  Importantly, it closes the onscreen window if its open.
        Screen('CloseAll');
        Priority(0);
        psychrethrow(psychlasterror);
    end

    %%%%%%%%%%%%%%%%%%%%%%%% Turn On PTB verbose warnings %%%%%%%%%%%%%%%%%%%%
    Screen('Preference', 'Verbosity', 3);
    % please see the following page for an explanation of this function
    %  http://psychtoolbox.org/FaqWarningPrefs
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    java.lang.Runtime.getRuntime().gc % call garbage collect (likely useless)

    return
