function [protocol, design] = makeHyperSpaceProtocol(design, quiet)
% MAKEHYPERSPACEPROTOCOL Build a randomized continuous-phase protocol.
% [protocol, design] = makeHyperSpaceProtocol();          % Preview only.
% [protocol, design] = makeHyperSpaceProtocol(design);    % Rebuild edits.
% Run it with HyperSpace_master_360dots('run_name', design).
% One trial = stationary baseline + movement. No implicit ITIs or repeats.
% This function does not open the display or start Open Ephys acquisition.

if nargin < 1 || isempty(design)
    % ------------------ EDIT THE EXPERIMENT HERE -----------------------
    design.InitialBlack_s = 5;
    design.Stationary_s = 20;
    design.Motion_s = 30;
    design.Directions_deg = [0, 180];
    design.Speeds_cm_s = [90, 180];
    [d, s] = ndgrid(1:numel(design.Directions_deg), ...
                    1:numel(design.Speeds_cm_s));
    design.Sequence = [d(:), s(:)]; % [direction INDEX, speed INDEX]
    design.BlockRepeats = 1;       % Actual number of blocks, not extra repeats.
    design.RandomizeWithinBlock = true;
    design.Seed = 1;               % Same seed -> same reproducible order.
    % -----------------------------------------------------------------
end

if nargin < 2, quiet = false; end

validateattributes(design.InitialBlack_s, {'numeric'}, {'scalar','real','finite','positive'});
validateattributes(design.Stationary_s, {'numeric'}, {'scalar','real','finite','positive'});
validateattributes(design.Motion_s, {'numeric'}, {'scalar','real','finite','positive'});
validateattributes(design.Directions_deg, {'numeric'}, {'vector','real','finite','nonempty'});
validateattributes(design.Speeds_cm_s, {'numeric'}, {'vector','real','finite','positive','nonempty'});
validateattributes(design.Sequence, {'numeric'}, ...
    {'2d','ncols',2,'real','finite','integer','positive','nonempty'});
assert(all(design.Sequence(:,1) <= numel(design.Directions_deg)), 'Invalid direction index.');
assert(all(design.Sequence(:,2) <= numel(design.Speeds_cm_s)), 'Invalid speed index.');
validateattributes(design.BlockRepeats, {'numeric'}, {'scalar','integer','positive','finite'});
validateattributes(design.Seed, {'numeric'}, {'scalar','integer','>=',0,'<=',2^32-1});
assert(islogical(design.RandomizeWithinBlock) && isscalar(design.RandomizeWithinBlock), ...
    'RandomizeWithinBlock must be true or false.');
previousRng = rng;
rngCleanup = onCleanup(@() rng(previousRng)); %#ok<NASGU>
rng(design.Seed, 'twister');

nPerBlock = size(design.Sequence,1);
nTrials = design.BlockRepeats*nPerBlock;
nPhases = 1+2*nTrials;
PhaseID = (1:nPhases)';
BlockID = zeros(nPhases,1);
TrialID = zeros(nPhases,1);
Mode = strings(nPhases,1);
Condition = strings(nPhases,1);
Duration_s = zeros(nPhases,1);
Heading_deg = nan(nPhases,1);
Speed_cm_s = zeros(nPhases,1);
Mode(1) = "black";
Condition(1) = "initial_black";
Duration_s(1) = design.InitialBlack_s;
row = 1;
trial = 0;
design.PresentedSequence = zeros(nTrials,2);
design.SourceRowOrder = zeros(design.BlockRepeats,nPerBlock);
for block = 1:design.BlockRepeats
    order = 1:nPerBlock;
    if design.RandomizeWithinBlock
        order = order(randperm(nPerBlock));
    end
    design.SourceRowOrder(block,:) = order;
    for sourceRow = order
        trial = trial+1;
        di = design.Sequence(sourceRow,1);
        si = design.Sequence(sourceRow,2);
        condition = string(sprintf('D%d_S%d',di,si));
        design.PresentedSequence(trial,:) = [di,si];
        row = row+1;
        BlockID(row) = block; TrialID(row) = trial;
        Mode(row) = "stationary"; Condition(row) = condition;
        Duration_s(row) = design.Stationary_s;
        row = row+1;
        BlockID(row) = block; TrialID(row) = trial;
        Mode(row) = "move"; Condition(row) = condition;
        Duration_s(row) = design.Motion_s;
        Heading_deg(row) = mod(design.Directions_deg(di),360);
        Speed_cm_s(row) = design.Speeds_cm_s(si);
    end
end
PlannedEnd_s = cumsum(Duration_s);
PlannedStart_s = [0;PlannedEnd_s(1:end-1)];
PhotodiodeValue = mod(PhaseID+1,2); % 0=black initial, 1=white stationary, 0=moving.
protocol = table(PhaseID,BlockID,TrialID,Mode,Condition,Duration_s, ...
    Heading_deg,Speed_cm_s,PlannedStart_s,PlannedEnd_s,PhotodiodeValue);
design.TotalNominalSeconds = PlannedEnd_s(end);
design.NumTrials = nTrials;
design.NumPhases = nPhases;
design.Name = 'HyperSpace';
design.ScheduleVersion = 'HyperSpace_phase_v1';
design.ScenePolicy = 'one persistent scene; freeze current image when stationary';
design.MarkerPolicy = 'Option 1: constant within phase; toggle at every boundary';
design.TimingMeaning = 'nominal seconds, quantized to display refreshes at run time';
assert(row==nPhases && trial==nTrials, 'Internal phase-count error.');
assert(all(abs(diff(PhotodiodeValue))==1), 'Marker must toggle at every boundary.');
if ~quiet
    fprintf('\nPLAN ONLY: %d phases, %d movement trials, %d blocks.\n', ...
        nPhases,nTrials,design.BlockRepeats);
    fprintf('Nominal duration: %.3f s (%.3f min). Photodiode: phase-boundary toggles.\n', ...
        design.TotalNominalSeconds,design.TotalNominalSeconds/60);
    fprintf('No display or acquisition has started.\n\n');
    disp(protocol);
end
end
