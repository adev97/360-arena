function [trials, meta] = HyperSpace_master_360dots(savename, design)
% HYPERSPACE_MASTER_360DOTS Run a continuous, phase-based HyperSpace protocol.
%
% [trials,meta] = HyperSpace_master_360dots('HyperSpace_run01');
% [protocol,design] = makeHyperSpaceProtocol();
% design.Motion_s = 3;   % Optional edits, rebuilt by this master.
% [trials,meta] = HyperSpace_master_360dots('HyperSpace_shortTest',design);
%
% Uses your existing getMonitorInformation, PixToLum, GammaCorrect,
% LeftBoxStim_small, and trialStructSave_360. The latter calls dirInformation_AD.
% Does NOT call trialStruct_RFmapFast_AD or stimInitScreen: the phase table
% defines every experiment interval and every repeat. Does not start OneBox.
% Saves once through trialStructSave_360 to dirInfo.DaqPCDataLoc.
% No separate local backup is created.
% Normal completion and ESC save full/partial logs. Caught display errors
% save known data first, then are rethrown. MATLAB crashes/power loss cannot
% be recovered by this end-of-run saving mechanism.

if nargin<1 || isempty(savename), savename = 'HyperSpace'; end
if nargin<2, design = []; end
savename = char(savename);
assert(isrow(savename) && ~isempty(regexp(savename,'^[A-Za-z0-9_-]+$','once')), ...
    'savename must contain only letters, digits, underscores, or hyphens.');
[protocol, design] = makeHyperSpaceProtocol(design);
monitorInfo = getMonitorInformation();
p = HyperSpaceWorld('defaults',monitorInfo);
R = monitorInfo.radius;
% ------------------- APPEARANCE / WORLD CONTROLS -----------------------
p.Num_Dots = 600;                % Expected visible centers BEFORE fades.
p.Depth_Min = 2*R;               % Visible near radial cutoff, cm.
p.Depth_Max = 3*R;               % Visible far radial cutoff, cm.
p.World_Geometry = 1;            % 1=vertical cylinder; 2=sphere.
p.Dot_Size_Min = 2;              % DIAMETER in pixels.
p.Dot_Size_Max = 4;
p.Boundary_Fade = 0.25*(p.Depth_Max-p.Depth_Min);
p.Vertical_Edge_Fade = 1.5;       % Degrees.
p.Dark_Background = 1;           % 1=white on black; 0=black/white on gray.
worldSeed = 1;                   % Separate from the condition-order seed.
user = 'AD';
tag = 'm001';
iftest = 1;                      % Your existing helper adds _test; still saves.
options.RecordResetEvents = true;
options.TerminalMarkerHold_s = 0.5; % OUTSIDE the scheduled protocol duration.
options.CleanupBlackHold_s = 0.25;   % OUTSIDE the scheduled protocol duration.
% ---------------------------------------------------------------------
HyperSpaceWorld('validate',p,monitorInfo);
requiredHelpers = {'PixToLum','GammaCorrect','LeftBoxStim_small','trialStructSave_360'};
for j = 1:numel(requiredHelpers)
    assert(~isempty(which(requiredHelpers{j})),'Missing helper: %s',requiredHelpers{j});
end
validateattributes(worldSeed,{'numeric'},{'scalar','integer','>=',0,'<=',2^32-1});
validateattributes(options.TerminalMarkerHold_s,{'numeric'},{'scalar','finite','positive'});
validateattributes(options.CleanupBlackHold_s,{'numeric'},{'scalar','finite','positive'});

rngBefore = rng;
rngCleanup = onCleanup(@() rng(rngBefore)); %#ok<NASGU>
rng(worldSeed,'twister');
meta = struct();
meta.name = 'HyperSpace'; meta.stimType = 'HyperSpace';
meta.user = user; meta.tag = tag; meta.iftest = iftest;
meta.monitorInfo = monitorInfo;
meta.parameters = p;
meta.protocol = protocol;
meta.design = design;
meta.rendererOptions = options;
meta.worldSeed = worldSeed;
meta.rngBeforeRun = rngBefore;
meta.flowModel = 'HyperSpace_persistentTranslation_v1';
meta.dateStr = char(datetime('now','Format','yyyyMMdd'));
meta.timestamp = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
meta.matlabVersion = version;
meta.photodiodeMeaning = ['Option 1: patch constant within phase; inversion on phase ', ...
    'transitions. First stationary onset is first optical edge. Terminal and ', ...
    'cleanup events are separately logged. No physical voltage is acquired here.'];
meta.depthMeaning = ['2R-3R is the visible radial window. Stars may fade out inside ', ...
    'the screen at its depth boundaries. Hidden reservoir is larger.'];
meta.projectionMeaning = 'Original linear azimuth/elevation-to-pixel arena mapping';
meta.countMeaning = 'Expected visible-center count before fades, not a fixed per-frame count';
sourceNames = {'HyperSpace_master_360dots.m','makeHyperSpaceProtocol.m', ...
    'displayHyperSpace_360LED.m','HyperSpaceWorld.m','HyperSpaceFrameClock.m', ...
    'getMonitorInformation.m','PixToLum.m','GammaCorrect.m','LeftBoxStim_small.m', ...
    'trialStructSave_360.m','dirInformation_AD.m'};
meta.sourceFiles = sourceNames;
meta.sourcePaths = cell(size(sourceNames));
meta.sourceText = cell(size(sourceNames));
for j = 1:numel(sourceNames)
    path = which(sourceNames{j});
    assert(~isempty(path),'Cannot resolve source file: %s',sourceNames{j});
    meta.sourcePaths{j} = path;
    meta.sourceText{j} = fileread(path);
end
fprintf('\nHyperSpace: %d phases, %d movement trials, %.3f nominal seconds.\n', ...
    height(protocol),design.NumTrials,design.TotalNominalSeconds);
fprintf('Photodiode: phase-boundary toggles. Start OneBox recording separately.\n');
fprintf('ESC aborts and saves a partial log through trialStructSave_360.\n\n');
[meta.displayLog, displayError] = displayHyperSpace_360LED(protocol,p,monitorInfo,options);

% A convenient top-level record for EACH stationary+movement pair.
ph = meta.displayLog.phases;
motionRows = find(ph.Mode=="move");
summary = ph(motionRows,{'TrialID','BlockID','Condition','Heading_deg','Speed_cm_s'});
summary.StationaryPhaseID = ph.PhaseID(motionRows-1);
summary.MovementPhaseID = ph.PhaseID(motionRows);
summary.BaselineOnsetPTB_s = ph.OnsetPTB_s(motionRows-1);
summary.MovementOnsetPTB_s = ph.OnsetPTB_s(motionRows);
summary.MovementOffsetPTB_s = ph.OffsetPTB_s(motionRows);
summary.MotionCompleted = ph.Completed(motionRows);
trials = table2struct(summary);
meta.movementTrials = summary;
meta.savedAfterStatus = meta.displayLog.status;
% Save trials and the complete meta structure once, using the configured directory.
try
    trialStructSave_360(trials,meta,savename,tag,iftest);
catch saveError
    fprintf(2,'STIMULUS SAVE FAILED: %s\n',saveError.message);
    if ~isempty(displayError)
        saveError = addCause(saveError,displayError);
    end
    rethrow(saveError);
end
if ~isempty(displayError), rethrow(displayError); end
fprintf('HyperSpace ended with status: %s\n',meta.displayLog.status);
end
