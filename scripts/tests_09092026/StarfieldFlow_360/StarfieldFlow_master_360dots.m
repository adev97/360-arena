function [trials, meta] = StarfieldFlow_master_360dots(savename)
% STARFIELDFLOW_MASTER_360DOTS Forward travel through a stationary star field.
% Use THIS master and displayStarfieldFlow_360LED, not the old convergence
% master/display. Pipeline: monitor -> existing trial builder -> display ->
% existing lab save helper. All table parameters below are constant.
%
% Num Dots is a TARGET MEAN count in the displayed depth/FOV window before
% fades, not the size of the invisible world reservoir or a fixed frame count.
% World Geometry: 1 = vertical cylinder, 2 = sphere. Bounds are RADII, not
% diameters; only rendered stars are required to be inside these bounds.
%
% Optional heading set below makes one copy of each nonblank base trial per
% heading, shuffling that set separately for each base trial when requested.
% Blank trials are kept once. The table's Heading value is a placeholder for
% that base condition; trials(k).Heading and meta.headingList are authoritative.

if nargin<1 || isempty(savename)
    savename = 'StarfieldFlow_360_600';
end
monitorInfo = getMonitorInformation();
R = monitorInfo.radius;
p = starfieldFlow360('defaults',monitorInfo);

% ------------------------- MAIN CONTROLS -------------------------------
p.Num_Dots = 600;                % expected centers in displayed window
p.Travel_Speed = 180;             % cm/s; 180 doubles forward speed
p.Depth_Min = 2*R;               % inner visible radius
p.Depth_Max = 3*R;               % outer visible radius
p.World_Geometry = 1;            % 1: vertical cylinder; 2: sphere
p.Dot_Size_Min = 2;              % DIAMETER in pixels
p.Dot_Size_Max = 4;              % DIAMETER in pixels
p.Boundary_Fade = 0.25*(p.Depth_Max-p.Depth_Min); % cm at each radial boundary
p.Vertical_Edge_Fade = 1.5;       % deg; thin top/bottom contrast taper
p.Dark_Background = 1;           % 1: white on black; 0: black/white on gray

headingList = 180;                 % simulated travel direction, in degrees
% headingList = [0, -60, -120, 180, 120, 60]; % six arena directions
randomizeHeadingOrder = false;   % per base trial, if multiple headings
randomSeed = 1;                  % change for a different reproducible run
% ---------------------------------------------------------------------
assert(isnumeric(headingList) && isvector(headingList) && ...
    ~isempty(headingList) && all(isfinite(headingList)), 'Invalid headingList.');
headingList = double(headingList(:)');
p.Heading = headingList(1);
starfieldFlow360('validate',p,monitorInfo);

stimulusTable = { ...
    'Num Dots',                    p.Num_Dots, [], []; ...
    'Depth Min (cm)',              p.Depth_Min, [], []; ...
    'Depth Max (cm)',              p.Depth_Max, [], []; ...
    'Dot Size Min (px)',           p.Dot_Size_Min, [], []; ...
    'Dot Size Max (px)',           p.Dot_Size_Max, [], []; ...
    'Travel Speed (cmps)',         p.Travel_Speed, [], []; ...
    'Heading (deg)',               p.Heading, [], []; ...
    'World Geometry',              p.World_Geometry, [], []; ...
    'Boundary Fade (cm)',          p.Boundary_Fade, [], []; ...
    'Vertical Edge Fade (deg)',     p.Vertical_Edge_Fade, [], []; ...
    'Dark Background',             p.Dark_Background, [], []; ...
    'Timing (delay,duration,wait)', 0, 45, 3; ...
    'Blank',                       0, [], []; ...
    'Randomize',                   0, [], []; ...
    'Interleave',                  0, [], []; ...
    'Repeats',                     1, [], []; ... % lab helper: 1 -> 2 base trials
    'Initialization Screen (s)',   5, [], []};
stimType = 'Starfield Flow';
user = 'AD';
tag = 'm001';
iftest = 1;

rngBeforeRun = rng;
rngCleanup = onCleanup(@() rng(rngBeforeRun)); %#ok<NASGU>
rng(randomSeed,'twister');
base = trialStruct_RFmapFast_AD(stimType,stimulusTable);
assert(~isempty(base), 'The trial builder returned no trials.');
% Explicit constant fields also cover Blank entries from the existing helper.
% Edit p above, not just a numeric table entry, to change a constant parameter.
parameterNames = fieldnames(p);
for k = 1:numel(base)
    for j = 1:numel(parameterNames)
        name = parameterNames{j};
        base(k).(name) = p.(name);
    end
    base(k).Flow_Model = 'starfieldTranslation_v1';
    base(k).Speed_Units = 'cm_per_s';
    base(k).Sequence_Index = 0;
    base(k).Base_Trial_Index = k;
end
trials = base([]);
for k = 1:numel(base)
    if strcmp(base(k).Stimulus_Type,'Blank')
        trials(end+1) = base(k); %#ok<AGROW>
    else
        order = 1:numel(headingList);
        if randomizeHeadingOrder
            order = order(randperm(numel(order)));
        end
        for j = order
            tr = base(k);
            tr.Heading = headingList(j);
            trials(end+1) = tr; %#ok<AGROW>
        end
    end
end
for k = 1:numel(trials)
    trials(k).Sequence_Index = k;
end

meta = struct();
meta.monitorInfo = monitorInfo;
meta.user = user;
meta.tag = tag;
meta.stimType = stimType;
meta.stimulusTable = stimulusTable;
meta.parameters = p;
meta.headingList = headingList;
meta.randomizeHeadingOrder = randomizeHeadingOrder;
meta.randomSeed = randomSeed;
meta.rngBeforeRun = rngBeforeRun;
meta.rngAfterTrialBuilder = rng;
meta.flowModel = 'starfieldTranslation_v1';
meta.speedMeaning = 'Common simulated observer translation speed, cm/s';
meta.countMeaning = 'Expected dot centers in visible depth/FOV window before attenuation';
meta.depthMeaning = ['Rendered radial window: 1=hypot(X,Z), 2=norm([X,Y,Z]); ', ...
    'unrendered reservoir extends beyond it; no near-boundary teleport'];
meta.projectionMeaning = ['Full 3-D azimuth/elevation mapped linearly to pixels, ', ...
    'as in the supplied rig renderer; not a new physical LED calibration'];
meta.dateStr = char(datetime('now','Format','yyyyMMdd'));
meta.timestamp = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
meta.matlabVersion = version;
% Preserve the exact new code used, together with the run configuration.
folder = fileparts(mfilename('fullpath'));
sourceNames = {'StarfieldFlow_master_360dots.m', ...
    'displayStarfieldFlow_360LED.m','starfieldFlow360.m'};
meta.sourceFiles = sourceNames;
meta.sourceText = cell(size(sourceNames));
for k = 1:numel(sourceNames)
    meta.sourceText{k} = fileread(fullfile(folder,sourceNames{k}));
end
fprintf('Star-field flow: %g cm/s; %d trials. Press ESC to abort.\n', ...
    p.Travel_Speed,numel(trials));
meta.displayLog = displayStarfieldFlow_360LED(trials,monitorInfo);
trialStructSave_360(trials,meta,savename,tag,iftest);
end
