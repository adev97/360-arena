%% random dot, optic flow stimulus creation for head fixed mice

%%%%%%% from claude %%%%%%%%
function trials = OpticFlow_master_360dots(savename)
% OPTICFLOW_MASTER_360DOTS - same 3-function structure as your RF mapping
% experiments (monitorInformation -> trialStruct_RFmapFast -> display
% function), driving the forward optic-flow dot-field stimulus on the
% 360deg LED arena instead of RF-mapping sectors.
%
% Every stimulus parameter is expressed as a table row, exactly like
% 'Square PositionX' was for RF mapping -- trialStruct_RFmapFast doesn't
% care what the parameters mean, only whether they vary. Right now
% nothing varies (forward motion, one speed, one dot-cloud config), so
% trialStruct_RFmapFast falls into its "repeat the constant trial
% Repeats+1 times" branch, giving Repeats+1 identical forward-flow
% trials -- exactly what a single-condition run needs.
%
% EXTENDING TO BACKWARD MOTION LATER: change the 'Self Motion Direction'
% row from a constant (e.g. 1, [], []) to a real varying param (e.g.
% -1, 2, 1, giving values [-1 1]) and set Randomize = 1. No other
% change needed -- trialStruct_RFmapFast will cross/shuffle/repeat the
% two directions automatically, same as it does for any other
% parameter.

monitorInformation;

table = {'Self Motion Direction (binary)', 1, [], [];...   % 1 = forward. -1 = backward (not yet used)
    'Self Motion Speed (cmps)', 30, [], [];...        % TUNE
    'Num Dots', 120, [], [];...
    'Depth Min (cm)', 5, [], [];...                   % TUNE -- virtual world units
    'Depth Max (cm)', 100, [], [];...                 % TUNE
    'Dot Size Base (px)', 6, [], [];...                % TUNE
    'Dot Size Min (px)', 1, [], [];...                 % TUNE
    'Dot Size Max (px)', 14, [], [];...                % TUNE
    'Dot Size RefDepth (cm)', 20, [], [];...           % TUNE
    'Dot Lifetime Min (s)', 0.5, [], [];...            % TUNE
    'Dot Lifetime Max (s)', 1.5, [], [];...            % TUNE
    'Timing (delay,duration,wait)', 0, 5, 3;...         % duration=5s flow, wait=3s ITI
    'Blank', 0, [], [];...
    'Randomize', 0, [], [];...                          % nothing to randomize yet (one condition)
    'Interleave', 0, [], [];...
    'Repeats', 2, [], [];...                           % 49 -> 50 
    'Initialization Screen (s)', 5, [], []};

stimType = 'Optic Flow';

trials = trialStruct_RFmapFast(stimType, table);
OpticFlow_360LED(trials);

if nargin < 1 || isempty(savename)
    savename = 'OpticFlowForward_100cmps'; % default if not supplied
end
trialStructSave(trials, savename, 'Trial01');

end

%%%%%%% from claude %%%%%%%%


%%% OG FROM KAI
% function OpticFlow_master_360dots(savename)
% 
% table = {'Square Size (deg)', 10, 1, 10;...
%     'Square PositionX (deg)', -145, 10, 145;...
%     'Square PositionY (deg)', -40, 10, 40;...
%     'Square Luminance (binary)', 0, 1, 1;...
%     'Timing (delay,duration,wait)', 0, 0.095, 0;...
%     'Blank', 0, [], [];
%     'Randomize', 1, [], [];...
%     'Interleave', 0, [], [];...
%     'Repeats', 2, [], [];... % if n after 'Repeats', then n+1 rounds in total , 2 FOR TESTING, USUALLY 49
% 
%     'Initialization Screen (s)', 5, [],[]};
% stimType = 'Receptive Field Mapping';
% 
% trials = trialStruct_RFmapFast(stimType, table);
% ReceptiveFieldMapping_Fast_360degLED(trials); %% this will change, likely OpticFlow_360LED(trials)
% 
% savename = 'Mouse09_RFmap_Fast_100ms_EB'; 
% trialStructSave(trials,savename, 'Trial01');
