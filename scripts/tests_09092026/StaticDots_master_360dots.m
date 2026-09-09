function trials = StaticDots_master_360dots(savename)
% STATICDOTS_MASTER_360DOTS - same 3-function structure as your RF
% mapping and optic-flow experiments (monitorInformation ->
% trialStruct_RFmapFast -> display function), driving the static
% random-dot-field stimulus on the 360deg LED arena.
%
% Every stimulus parameter is expressed as a table row, exactly like
% 'Square PositionX' was for RF mapping -- trialStruct_RFmapFast doesn't
% care what the parameters mean, only whether they vary. Right now
% nothing varies (one dot-cloud config), so trialStruct_RFmapFast falls
% into its "repeat the constant trial Repeats+1 times" branch, giving
% Repeats+1 identical static-dot trials -- exactly what a
% single-condition run needs.
%
% Unlike OpticFlow_master_360dots.m, there is no self-motion, no dot
% lifetime, and no depth-dependent size falloff here -- the dots are
% static for the whole trial, so those rows are simply omitted from the
% table (displayStaticDots_360LED.m doesn't read them).

monitorInfo = getMonitorInformation();
R_arena = monitorInfo.radius;

table = {'Num Dots', 300, [], [];...
'Depth Min (cm)', 2*R_arena, [], [];...            % inner diameter of virtual world (2 * arena radius)
'Depth Max (cm)', 3*R_arena, [], [];...            % outer diameter of virtual world (3 * arena radius)
'Dot Size Min (px)', 2, [], [];...                 % TUNE
'Dot Size Max (px)', 12, [], [];...                % TUNE
'Timing (delay,duration,wait)', 0, 20, 3;...         % duration=20s static dots, wait=3s ITI
'Blank', 0, [], [];...
'Randomize', 0, [], [];...                          % nothing to randomize yet (one condition)
'Interleave', 0, [], [];...
'Repeats', 1, [], [];...                           % 19 -> 20 trials total. LOWER FOR TESTING
'Initialization Screen (s)', 5, [], []};

stimType = 'Static Dots';
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

displayStaticDots_360LED(trials);

if nargin < 1 || isempty(savename)
    savename = 'StaticDots'; % default if not supplied
end
trialStructSave_360(trials, meta, savename, tag, iftest);

end

function monitorInfo = getMonitorInformation()
%   monitorInfo = getMonitorInformation()
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file contains all the monitor information for the 360 Neuropixel arena;
% all information is stored in a monitor structure
%%%%%%%%%%%%%%%%%%%%%%%% MONITOR INFORMATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
monitorInfo.screenNumber = 2;
monitorInfo.screenSizeDegX = 360;
monitorInfo.screenSizeDegY = 90;
monitorInfo.screenSizePixX = 960;
monitorInfo.screenSizePixY = 240;
monitorInfo.degPerPix = monitorInfo.screenSizeDegX/...
    monitorInfo.screenSizePixX;
monitorInfo.radius = 61/2; % cm
monitorInfo.powerLawScaleFactor = .0001801;
monitorInfo.gamma = 2.386;
end
