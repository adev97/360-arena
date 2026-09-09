function trials = ConvergingDots_master_360dots(savename)
% CONVERGINGDOTS_MASTER_360DOTS - same 3-function structure as your RF
% mapping, optic-flow, and static-dots experiments (monitorInformation
% -> trialStruct_RFmapFast -> display function), driving the
% converging-dot-field stimulus on the 360deg LED arena: dots spawn the
% same way as the static dot field, then all move in true 3D space
% toward a single fixed target point -- azimuth 0deg, elevation 0deg,
% depth = the midpoint of the dot cloud's own depth shell (i.e. the
% middle of the virtual-world cylinder, (Depth_Min+Depth_Max)/2) -- and
% disappear permanently on arrival.
%
% Every stimulus parameter is expressed as a table row, exactly like
% 'Square PositionX' was for RF mapping -- trialStruct_RFmapFast doesn't
% care what the parameters mean, only whether they vary. Right now
% nothing varies (one dot-cloud config, one convergence speed), so
% trialStruct_RFmapFast falls into its "repeat the constant trial
% Repeats+1 times" branch, giving Repeats+1 identical converging-dot
% trials -- exactly what a single-condition run needs.
%
% Same as StaticDots_master_360dots.m, there is no self-motion-in-depth
% and no dot lifetime here, so those rows are simply omitted (
% displayConvergingDots_360LED.m doesn't read them). The only new row
% relative to the static-dots table is 'Convergence Speed (cmps)',
% which controls how fast every dot moves through 3D space toward the
% target point -- note this is cm/s (a real 3D speed), not deg/s, since
% the motion is now a straight-line interpolation of each dot's actual
% (X,Y,Z) position, not of its azimuth/elevation. The target point's
% depth is derived from Depth_Min/Depth_Max, not hardcoded, so it always
% sits at the middle of whatever depth shell you configure.

monitorInfo = getMonitorInformation();
R_arena = monitorInfo.radius;

table = {'Num Dots', 300, [], [];...
'Depth Min (cm)', 2*R_arena, [], [];...            % inner diameter of virtual world (2 * arena radius) -- spawn only
'Depth Max (cm)', 3*R_arena, [], [];...            % outer diameter of virtual world (3 * arena radius) -- spawn only
'Dot Size Min (px)', 2, [], [];...                 % TUNE
'Dot Size Max (px)', 12, [], [];...                % TUNE
'Convergence Speed (cmps)', 30, [], [];...         % 3D speed of every dot toward the target point (cm/s)
'Timing (delay,duration,wait)', 0, 20, 3;...         % duration=20s converging dots, wait=3s ITI
'Blank', 0, [], [];...
'Randomize', 0, [], [];...                          % nothing to randomize yet (one condition)
'Interleave', 0, [], [];...
'Repeats', 1, [], [];...                           % 19 -> 20 trials total. LOWER FOR TESTING
'Initialization Screen (s)', 5, [], []};

stimType = 'Converging Dots';
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

displayConvergingDots_360LED(trials);

if nargin < 1 || isempty(savename)
    savename = 'ConvergingDots_300'; % default if not supplied
end
trialStructSave_360(trials, meta, savename, tag, iftest);

end

