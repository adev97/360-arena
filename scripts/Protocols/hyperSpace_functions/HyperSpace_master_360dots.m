function [trials, meta] = HyperSpace_master_360dots(savename, design)
% HYPERSPACE_MASTER_360DOTS Run a continuous, phase-based HyperSpace protocol.
%
% Saves one MAT file containing:
%   trials
%   meta
%
% The renderer can generate a detailed displayLog internally, but only a
% compact subset needed for stimulus/ephys alignment and run QC is saved.
%
% [trials,meta] = HyperSpace_master_360dots('HyperSpace_run01');
%
% [protocol,design] = makeHyperSpaceProtocol();
% design.Motion_s = 3;
% [trials,meta] = HyperSpace_master_360dots('HyperSpace_shortTest',design);

if nargin < 1 || isempty(savename)
    savename = 'HyperSpace';
end

if nargin < 2
    design = [];
end

savename = char(savename);

assert(isrow(savename) && ...
    ~isempty(regexp(savename,'^[A-Za-z0-9_-]+$','once')), ...
    'savename must contain only letters, digits, underscores, or hyphens.');

%% Build protocol

[protocol, design] = makeHyperSpaceProtocol(design);

monitorInfo = getMonitorInformation();

p = HyperSpaceWorld('defaults',monitorInfo);

R = monitorInfo.radius;


%% ---------------- APPEARANCE / WORLD CONTROLS ------------------------

p.Num_Dots = 600;

p.Depth_Min = 2*R;
p.Depth_Max = 3*R;

p.World_Geometry = 1;

p.Dot_Size_Min = 2;
p.Dot_Size_Max = 4;

p.Boundary_Fade = 0.25*(p.Depth_Max-p.Depth_Min);
p.Vertical_Edge_Fade = 1.5;

p.Dark_Background = 1;

worldSeed = 1;

user = 'AD';
tag = 'm001';

iftest = 1;

options.RecordResetEvents = true;

options.TerminalMarkerHold_s = 0.5;
options.CleanupBlackHold_s = 0.25;

%% ---------------------------------------------------------------------

HyperSpaceWorld('validate',p,monitorInfo);

requiredHelpers = { ...
    'PixToLum', ...
    'GammaCorrect', ...
    'LeftBoxStim_small', ...
    'trialStructSave_360'};

for j = 1:numel(requiredHelpers)
    assert(~isempty(which(requiredHelpers{j})), ...
        'Missing helper: %s', requiredHelpers{j});
end

validateattributes(worldSeed,{'numeric'}, ...
    {'scalar','integer','>=',0,'<=',2^32-1});

validateattributes(options.TerminalMarkerHold_s,{'numeric'}, ...
    {'scalar','finite','positive'});

validateattributes(options.CleanupBlackHold_s,{'numeric'}, ...
    {'scalar','finite','positive'});


%% RNG

rngBefore = rng;

rngCleanup = onCleanup(@() rng(rngBefore)); %#ok<NASGU>

rng(worldSeed,'twister');


%% Metadata
%
% Keep experiment-defining information, but do not embed source code,
% repeated protocol tables, world states, RNG snapshots, or reset events.

meta = struct();

meta.name = 'HyperSpace';
meta.stimType = 'HyperSpace';

meta.user = user;
meta.tag = tag;
meta.iftest = iftest;

meta.timestamp = char(datetime('now', ...
    'Format','yyyy-MM-dd HH:mm:ss'));

meta.matlabVersion = version;


% Physical/display configuration
meta.monitorInfo = monitorInfo;


% HyperSpace visual/world parameters
meta.parameters = p;


% Experimental design:
% directions, speeds, sequence, randomization, durations, etc.
meta.design = design;


% Renderer settings that affect experiment behavior
meta.rendererOptions = options;

meta.worldSeed = worldSeed;

meta.flowModel = 'HyperSpace_persistentTranslation_v1';


%% Interpretation metadata

meta.photodiodeMeaning = [ ...
    'Option 1: patch constant within phase; inversion on phase transitions. ', ...
    'First stationary onset is first optical edge. Terminal and cleanup ', ...
    'events are outside the experimental phase table. Photodiode values ', ...
    'stored here are commanded values, not measured OneBox voltage.'];

meta.depthMeaning = [ ...
    '2R-3R is the visible radial window. Stars may fade at the depth ', ...
    'boundaries. The persistent world reservoir extends beyond this window.'];

meta.projectionMeaning = ...
    'Original linear azimuth/elevation-to-pixel arena mapping';

meta.countMeaning = ...
    'Num_Dots specifies expected visible-center count before fades';

meta.timeBase = ...
    'PTB timestamps are Psychtoolbox/system time, not Open Ephys time.';


%% Run protocol

fprintf('\nHyperSpace: %d phases, %d movement trials, %.3f nominal seconds.\n', ...
    height(protocol), ...
    design.NumTrials, ...
    design.TotalNominalSeconds);

fprintf(['Photodiode: phase-boundary toggles. ', ...
    'Start OneBox recording separately.\n']);

fprintf('ESC aborts and saves a partial log.\n\n');


% Keep the FULL display log temporarily in memory.
% We will reduce it before saving.
[displayLog, displayError] = ...
    displayHyperSpace_360LED(protocol,p,monitorInfo,options);


%% Generate trial-level summary

ph = displayLog.phases;

motionRows = find(ph.Mode == "move");

summary = ph(motionRows, ...
    {'TrialID', ...
     'BlockID', ...
     'Condition', ...
     'Heading_deg', ...
     'Speed_cm_s'});


summary.StationaryPhaseID = ...
    ph.PhaseID(motionRows-1);

summary.MovementPhaseID = ...
    ph.PhaseID(motionRows);


summary.BaselineOnsetPTB_s = ...
    ph.OnsetPTB_s(motionRows-1);

summary.MovementOnsetPTB_s = ...
    ph.OnsetPTB_s(motionRows);

summary.MovementOffsetPTB_s = ...
    ph.OffsetPTB_s(motionRows);

summary.MotionCompleted = ...
    ph.Completed(motionRows);


trials = table2struct(summary);


%% Reduce display log before saving
%
% displayHyperSpace_360LED still collects the detailed information during
% execution. This prevents changes to stimulus behavior.
%
% Only the information useful for:
%   1. Open Ephys / photodiode synchronization
%   2. determining the actual stimulus condition
%   3. timing QC
% is retained in the MAT file.

meta.displayLog = localLeanDisplayLog(displayLog);

meta.savedAfterStatus = displayLog.status;


%% Save one MAT file

try

    trialStructSave_360( ...
        trials, ...
        meta, ...
        savename, ...
        tag, ...
        iftest);

catch saveError

    fprintf(2, ...
        'STIMULUS SAVE FAILED: %s\n', ...
        saveError.message);

    if ~isempty(displayError)
        saveError = addCause(saveError,displayError);
    end

    rethrow(saveError);

end


%% Propagate renderer error after saving partial data

if ~isempty(displayError)
    rethrow(displayError);
end


fprintf( ...
    'HyperSpace ended with status: %s\n', ...
    displayLog.status);

end



%% =====================================================================
%                    LOCAL LOG-REDUCTION FUNCTION
% ======================================================================

function lean = localLeanDisplayLog(displayLog)
% LOCALLEANDISPLAYLOG
%
% Reduce the detailed renderer log to the information required for:
%
%   - matching photodiode transitions to stimulus phases
%   - mapping PTB time into Open Ephys time
%   - reconstructing actual stimulus timing
%   - checking dropped / delayed display frames
%
% This function does NOT alter stimulus execution. Reduction happens only
% after displayHyperSpace_360LED has finished.

lean = struct();


%% Run state

lean.status = displayLog.status;
lean.aborted = displayLog.aborted;
lean.error = displayLog.error;


%% Phase timing
%
% Keep the complete phase table because it is very small and contains both
% planned stimulus information and actual measured PTB timestamps.

lean.phases = displayLog.phases;


%% Per-frame timing
%
% PhaseID connects each frame to lean.phases.
%
% TrialID and BlockID are intentionally omitted because they can be obtained
% from PhaseID through lean.phases.

frameVariables = { ...
    'GlobalFrameID', ...
    'PhaseID', ...
    'PhaseFrameIndex', ...
    'VBLTime_s', ...
    'OnsetPTB_s', ...
    'PhotodiodeValue', ...
    'Missed_s', ...
    'SkippedLogicalFrames'};

lean.frames = displayLog.frames(:,frameVariables);


%% Display timing

if isfield(displayLog,'ifiSeconds')
    lean.ifiSeconds = displayLog.ifiSeconds;
end


%% End-of-run optical markers
%
% These occur outside the experimental phase table but are useful when
% interpreting the photodiode recording.

lean.terminal = displayLog.terminal;
lean.cleanupBlack = displayLog.cleanupBlack;


%% Timing QC

lean.nFrames = displayLog.nFrames;

lean.nPhasesStarted = ...
    displayLog.nPhasesStarted;

lean.nPositiveMissedFlags = ...
    displayLog.nPositiveMissedFlags;

lean.nLongFrameIntervals = ...
    displayLog.nLongFrameIntervals;


%% Clock interpretation

lean.timeBase = displayLog.timeBase;

lean.photodiodeMeaning = ...
    displayLog.photodiodeMeaning;


if isfield(displayLog,'motionTimingPolicy')
    lean.motionTimingPolicy = ...
        displayLog.motionTimingPolicy;
end

end