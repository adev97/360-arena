%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function trials = LinearSweep_master_360dots(savename)
% LINEARSWEEP_MASTER_360DOTS - same 3-function structure as your other 360-
% arena scripts (getMonitorInformation -> trialStruct_RFmapFast_AD ->
% display function), driving a "hyperspace"-style dot field: dots spawn
% randomly and sit stationary, then stream apart from a chosen vanishing-
% point azimuth (radiating outward in azimuth only, no depth/Z simulation),
% then freeze in their final position.
%
% VANISHING POINT / DIRECTION: 'Sweep Direction (1-6)' selects which of 6
% evenly-spaced (60 deg apart) azimuths, relative to the mouse's forward
% view (azimuth 0 = straight ahead, decreasing azimuth = left), acts as
% the point dots radiate away from:
%   1 = Front       (0 deg)
%   2 = Front-Left  (-60 deg)
%   3 = Back-Left   (-120 deg)
%   4 = Back        (180 deg)
%   5 = Back-Right  (120 deg)
%   6 = Front-Right (60 deg)
% Dots on the clockwise side of the vanishing point keep moving further
% clockwise (away); dots on the counter-clockwise side keep moving further
% counter-clockwise (away) -- same angular speed for every dot, so the
% field splits and streams apart from that one point, rather than the
% whole field rotating together.
%
% SWEEP DISTANCE: 'Sweep Distance (cm)' is the arc-length equivalent of
% the total angular displacement each dot travels during the sweep,
% converted using the arena radius (monitorInfo.radius).
%
% TRIAL STRUCTURE (per repeat): Static_Duration (dots frozen at spawn) ->
% Sweep_Duration (dots stream apart from the vanishing point) ->
% Freeze_Duration (dots frozen at their post-sweep position) -> ITI (gray
% gap before the next repeat; added here as a reasonable default since it
% wasn't specified -- set to 0 to disable).
%
% Everything below is currently a constant (single condition), same as
% OpticFlow_master_360dots -- trialStruct_RFmapFast_AD will repeat this
% one condition Repeats+1 times. Sweep Direction is a fixed value for
% now; can be extended to vary/randomize across trials later the same way
% other parameters are extended (give it a start:step:stop range and set
% Randomize = 1).
monitorInfo = getMonitorInformation();

table = {'Sweep Direction (1-6)', 1, [], [];...     % 1=Front 2=Front-Left 3=Back-Left 4=Back 5=Back-Right 6=Front-Right
    'Sweep Distance (cm)', 50, [], [];...               % TUNE -- total arc length each dot travels away from the vanishing point
    'Num Dots', 300, [], [];...
    'Dot Size Min (px)', 2, [], [];...                  % TUNE -- used directly as dot radius, matching OpticFlow convention
    'Dot Size Max (px)', 12, [], [];...                 % TUNE
    'Static Duration (s)', 15, [], [];...               % dots stationary before the sweep
    'Sweep Duration (s)', 15, [], [];...                % duration of the outward hyperspace sweep
    'Freeze Duration (s)', 15, [], [];...                % dots frozen in final position after the sweep
    'ITI (s)', 3, [], [];...                            % TUNE -- gray gap between repeats (added as a default; set to 0 to disable)
    'Blank', 0, [], [];...
    'Randomize', 0, [], [];...                          % nothing to randomize yet (one condition)
    'Interleave', 0, [], [];...
    'Repeats', 1, [], [];...                            % LOWER/RAISE FOR TESTING vs real experiment
    'Initialization Screen (s)', 5, [], []};

stimType = 'Linear Sweep';
user = 'AD'; % experimenter initials
tag = 'm001'; % change for which mouse it is (m - male, f - female)
iftest = 1; % if this is a test run, 1, if not a test run, 0
trials = trialStruct_RFmapFast_AD(stimType, table);

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

displayLinearSweep_360LED(trials);

if nargin < 1 || isempty(savename)
    savename = 'LinearSweep_Hyperspace'; % default if not supplied
end
trialStructSave_360(trials, meta, savename, tag, iftest);
end
