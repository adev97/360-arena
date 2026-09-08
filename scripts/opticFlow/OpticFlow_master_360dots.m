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
% Change 'Self Motion Direction' below to
% 1 for a single backward (contracting) run -- OpticFlow_360LED.m now
% handles both directions' depth-boundary respawn correctly. To have
% BOTH directions within one randomized/repeated run, change the row to
% a real varying param (-1, 2, 1, giving values [-1 1]) and set
% Randomize = 1; trialStruct_RFmapFast will cross/shuffle/repeat both
% directions automatically, same as it does for any other parameter.

monitorInfo = getMonitorInformation();

R_arena = monitorInfo.radius;

table = {'Self Motion Direction (binary)', -1, [], [];...   % -1 = forward. 1 = backward
         'Self Motion Speed (cmps)', 15, [], [];...        % TUNE
         'Num Dots', 300, [], [];...
         'Depth Min (cm)', 2*R_arena, [], [];...            % inner diameter of virtual world (2 * arena radius)
         'Depth Max (cm)', 3*R_arena, [], [];...            % outer diameter of virtual world (2 * arena radius)
         'Dot Size Min (px)', 2, [], [];...                 % TUNE
         'Dot Size Max (px)', 12, [], [];...                % TUNE
         'Dot Size RefDepth (cm)', 5, [], [];...           % TUNE -- distance past rMin where size hits the halfway point
         'Dot Lifetime Min (s)', 2, [], [];...            % TUNE
         'Dot Lifetime Max (s)', 4, [], [];...            % TUNE
         'Timing (delay,duration,wait)', 0, 20, 3;...         % duration=5s flow, wait=3s ITI
         'Blank', 0, [], [];...
         'Randomize', 0, [], [];...                          % nothing to randomize yet (one condition)
         'Interleave', 0, [], [];...
         'Repeats', 1, [], [];...                           % 19 -> 20 trials total. LOWER FOR TESTING
         'Initialization Screen (s)', 5, [], []};

stimType = 'Optic Flow';
user = 'AD'; % experimenter initials
tag = 'm001'; % change for which mouse it is (m - male, f - female)
iftest = 1; % if this is a test run, 1, if not a test run, 0
trials = trialStruct_RFmapFast_AD(stimType, table); % unchanged from Elissa's script

% Metadata: what code/config/rig/session produced this trials struct, so
% it's saved alongside the data instead of only living in this script.
meta.monitorInfo    = monitorInfo;
meta.user            = user;
meta.tag             = tag;
meta.stimType        = stimType;
meta.stimulusTable   = table;
nowTime              = datetime('now');
meta.dateStr         = char(datetime(nowTime, 'Format', 'yyyyMMdd'));
meta.timestamp       = char(datetime(nowTime, 'Format', 'yyyy-MM-dd HH:mm:ss'));
meta.matlabVersion   = version;

displayOpticFlow_360LED(trials);

if nargin < 1 || isempty(savename)
    savename = 'OpticFlowForward_100cmps'; % default if not supplied
end

trialStructSave_360(trials, meta, savename, tag, iftest);

%% try doing something where its fixed and then suddenly moves in one direction
% and try keeping all the dots on the screen during optic flow
% findout why they are clustering in the back

end
