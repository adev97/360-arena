function [trials, meta] = LinearSweep_master_360dots(savename)
% LINEARSWEEP_MASTER_360DOTS  Recycled moving dots in a bounded 3-D world.
% Workflow: master -> trialStruct_RFmapFast_AD -> displayLinearSweep_360LED.
%
% r = monitorInfo.radius, in cm. Inner and outer boundaries are 2*r and 3*r.
% World Geometry 1: cylindrical annulus, radius = hypot(X,Z).
% World Geometry 2: spherical shell, radius = sqrt(X.^2+Y.^2+Z.^2).
% The original 2r/3r source was not available; geometry 1 is an explicit
% default, NOT a claim that the old world was cylindrical.
%
% Local X = right, Y = up, Z = toward the selected direction.
% Flow Sign +1: dots converge toward that direction (back-to-front flow).
% Flow Sign -1: dots expand away from it (forward-observer-travel flow).
% Between boundary resets, only Z changes; dot sizes/colors stay fixed.
% Both inner and outer boundaries recycle dots, keeping the shell populated.
% There are no line-rendering or motion-history parameters.
%
% Required existing lab helpers: getMonitorInformation, PixToLum,
% GammaCorrect, stimInitScreen, trialStructSave_360. Requires Psychtoolbox.

if nargin < 1 || isempty(savename)
    savename = 'Hyperspace_360_Continuous_2r3r';
end
monitorInfo = getMonitorInformation();

stimulusTable = { ...
    'Sweep Direction (1-6)',           1, [], []; ...
    'Flow Sign (-1 expand, +1 contract)', 1, [], []; ...
    'World Geometry (1 cylinder, 2 sphere)', 1, [], []; ...
    'Inner Radius (arena r)',          2, [], []; ...
    'Outer Radius (arena r)',          3, [], []; ...
    'Virtual Travel (cm)',            150, [], []; ...
    'Motion Exponent',                1, [], []; ...
    'Num Dots',                     300, [], []; ...
    'Dot Size Min (px radius)',        1, [], []; ...
    'Dot Size Max (px radius)',        2, [], []; ...
    'Dark Background',                1, [], []; ...
    'Static Duration (s)',           5, [], []; ...
    'Sweep Duration (s)',            15, [], []; ...
    'Freeze Duration (s)',           5, [], []; ...
    'ITI (s)',                        3, [], []; ...
    'Random Seed',                    1, [], []; ...
    'Blank',                          0, [], []; ...
    'Randomize',                      0, [], []; ...
    'Interleave',                     0, [], []; ...
    'Repeats',                        0, [], []; ...
    'Initialization Screen (s)',      5, [], []};

% Sweep Direction: 1 front (0), 2 front-left (-60), 3 back-left (-120),
%                  4 back (180), 5 back-right (120), 6 front-right (60).
% Flow Sign +1 matches the latest request for front-converging flow.
% Set Flow Sign to -1 for the earlier front-expanding hyperspace effect.
% Virtual Travel is displacement through the virtual scene, NOT arena arc.
% Motion Exponent 1 = constant virtual speed; 2 = linearly increasing speed.
% Dark Background 1 = white dots on black; 0 = black/white dots on mid-gray.
% Initialization and ITI are mid-gray. Repeats 1 means TWO presentations.
% To vary directions: 'Sweep Direction (1-6)', 1, 1, 6; then Randomize = 1.
% Keep Blank = 0 and Interleave = 0; this renderer does not implement them.

% RIG MAPPING: retained from the previous replacement. This assumes one
% unwrapped rectangular 360-degree panorama, not a rearranged panel atlas.
% Confirm where physical front is on the rig; it need not be framebuffer x=0.
arenaMap.rect = [0, 0, round(360 / monitorInfo.degPerPix), ...
    round(monitorInfo.screenSizeDegY / monitorInfo.degPerPix)];
arenaMap.azimuthZeroXFraction = 0;
arenaMap.azimuthSign = 1;
arenaMap.verticalProjection = 'angular';
% 'angular' preserves your original elevation-to-pixel formula.
% 'cylindrical' is for unwarped, equally spaced physical LED rows, with the
% eye at the cylinder center and vertical midpoint. This SCREEN mapping is
% independent of the World Geometry parameter above.

stimType = 'Linear Sweep';
user = 'AD';
tag = 'm001';
iftest = 1;  % Used by your save helper; does not enable a desktop preview.

meta.rngBeforeTrialBuilder = rng;
trials = trialStruct_RFmapFast_AD(stimType, stimulusTable);
meta.monitorInfo = monitorInfo;
meta.arenaMap = arenaMap;
meta.user = user;
meta.tag = tag;
meta.stimType = stimType;
meta.motionModel = 'bounded 3-D world; inner/outer periodic recycling';
meta.stimulusTable = stimulusTable;
meta.geometryAssumption = ...
    'Geometry selection is explicit; original 2r/3r renderer was unavailable.';
nowTime = datetime('now');
meta.dateStr = char(datetime(nowTime, 'Format', 'yyyyMMdd'));
meta.timestamp = char(datetime(nowTime, 'Format', 'yyyy-MM-dd HH:mm:ss'));
meta.matlabVersion = version;
meta.masterSource = fileread([mfilename('fullpath') '.m']);
meta.rendererSource = fileread(which('displayLinearSweep_360LED'));
meta.trialBuilderSource = fileread(which('trialStruct_RFmapFast_AD'));

% Escape returns a partial presentation log and then saves it here.
% Other errors are rethrown by the renderer; they are not silently ignored.
meta.presentation = displayLinearSweep_360LED(trials, monitorInfo, arenaMap);
trialStructSave_360(trials, meta, savename, tag, iftest);
end
