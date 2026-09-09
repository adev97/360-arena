function trials = ConvergingDotsLoop_master_360dots(savename)
% CONVERGINGDOTSLOOP_MASTER_360DOTS - same 3-function structure as your RF
% mapping, optic-flow, static-dots, and converging-dots experiments
% (monitorInformation -> trialStruct_RFmapFast -> display function),
% driving the SEAMLESSLY-LOOPING converging-dot-field stimulus on the
% 360deg LED arena: dots spawn the same way as the static dot field,
% then all move in true 3D space toward a single fixed target point --
% azimuth 0deg, elevation 0deg, depth = the midpoint of the dot cloud's
% own depth shell (i.e. the middle of the virtual-world cylinder,
% (Depth_Min+Depth_Max)/2) -- but instead of disappearing permanently
% on arrival (as in ConvergingDots_master_360dots.m /
% displayConvergingDots_360LED.m), each dot immediately reappears at
% the antipodal point on the arena (azimuth+180deg, elevation
% mirrored) at a freshly-sampled depth within the same shell, and keeps
% converging -- giving the illusion of a perfectly seamless, endless
% inward flow with no dots ever truly disappearing for the trial.
%
% Every stimulus parameter is expressed as a table row, exactly like
% 'Square PositionX' was for RF mapping -- trialStruct_RFmapFast doesn't
% care what the parameters mean, only whether they vary. Right now
% nothing varies (one dot-cloud config, one convergence speed), so
% trialStruct_RFmapFast falls into its "repeat the constant trial
% Repeats+1 times" branch, giving Repeats+1 identical looping-converging
% -dot trials -- exactly what a single-condition run needs.
%
% Same as ConvergingDots_master_360dots.m, there is no self-motion-in-
% depth and no dot lifetime here, so those rows are simply omitted (
% displayConvergingDotsLoop_360LED.m doesn't read them). The table is
% otherwise identical to the non-looping converging-dots table --
% 'Convergence Speed (cmps)' still controls how fast every dot moves
% through 3D space toward the target point (cm/s, a real 3D speed, not
% deg/s), and the target point's depth is still derived from
% Depth_Min/Depth_Max rather than hardcoded. The only thing that
% differs is what the display function does the instant a dot arrives
% at the target: it loops (respawns at the antipode) instead of
% retiring for good.
monitorInfo = getMonitorInformation();
R_arena = monitorInfo.radius;
table = {'Num Dots', 600, [], [];...
'Depth Min (cm)', 2*R_arena, [], [];...            % inner diameter of virtual world (2 * arena radius) -- spawn only
'Depth Max (cm)', 3*R_arena, [], [];...            % outer diameter of virtual world (3 * arena radius) -- spawn only
'Dot Size Min (px)', 6, [], [];...                 % TUNE
'Dot Size Max (px)', 12, [], [];...                % TUNE
'Convergence Speed (cmps)', 30, [], [];...         % 3D speed of every dot toward the target point (cm/s)
'Arrival Radius (cm)', 1.25*R_arena, [], [];...    % TUNE (see note below): dot "arrives"/loops once within this distance of the target -- larger values cut off the front-crowded near-target crawl sooner, at the cost of the convergence point looking less pinpoint. Default here is ~30% of target depth (2.5*R_arena); try scaling this up (e.g. toward 1-1.5*R_arena) if the field still looks front-heavy.
'Timing (delay,duration,wait)', 0, 20, 3;...         % duration=20s looping converging dots, wait=3s ITI
'Blank', 0, [], [];...
'Randomize', 0, [], [];...                          % nothing to randomize yet (one condition)
'Interleave', 0, [], [];...
'Repeats', 1, [], [];...                           % 19 -> 20 trials total. LOWER FOR TESTING
'Initialization Screen (s)', 5, [], []};
stimType = 'Converging Dots Loop';
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
displayConvergingDotsLoop_360LED(trials);
if nargin < 1 || isempty(savename)
    savename = 'ConvergingDotsLoop_300'; % default if not supplied
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
