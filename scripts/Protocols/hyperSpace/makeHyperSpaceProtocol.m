function [protocol, design] = makeHyperSpaceProtocol()
% MAKEHYPERSPACEPROTOCOL Build and preview a continuous-phase experiment plan.
%
%   [protocol, design] = makeHyperSpaceProtocol();
%
% This function ONLY builds a schedule. It does not open Psychtoolbox,
% modify the existing starfield scripts, draw a photodiode patch, or acquire
% OneBox data. The old displayStarfieldFlow_360LED (hyperSpace folder) cannot consume this table
% directly: continuous phases require a persistent-world renderer.
%
% One trial = stationary baseline + one movement presentation.
% One block = all rows of design.Sequence (including deliberate duplicates).
% The initial black phase occurs ONCE, not once per block.
% PlannedStart_s and PlannedEnd_s are nominal schedule times, NOT measured
% onsets, PTB timestamps, or times in the OneBox recording.

% --------------------- EDIT THE EXPERIMENT HERE ------------------------
design.InitialBlack_s = 5;
design.Stationary_s = 20;
design.Motion_s = 30;                 % Example, based on your current master.

design.Directions_deg = [0, 60, 120, 180, 240, 300];     % Direction 1, direction 2: examples.
design.Speeds_cm_s = [45, 90, 180];       % Speed 1, speed 2: examples.

% Each row is [direction INDEX, speed INDEX], not literal deg or cm/s.
% this block includes every direction-speed combination automatically
[directionIndex, speedIndex] = ndgrid( ...
    1:numel(design.Directions_deg), ...
    1:numel(design.Speeds_cm_s));

design.Sequence = [directionIndex(:), speedIndex(:)];

% For one presentation of every direction-speed combination, change the
% last row to [2, 2]. Do not change it unless that is the intended protocol.

design.BlockRepeats = 1;             % Actual count: 1 means ONE block.
design.RandomizeWithinBlock = true;
design.Seed = 1;
% ---------------------------------------------------------------------

% Explicit policies for the future continuous-phase renderer.
design.ScenePolicy = 'one persistent scene; no resets between phases';
design.StationaryPolicy = 'freeze positions, sizes, polarity, and fade values';
design.BlackPolicy = 'hide stars and freeze world; do not regenerate stars';
design.TransitionPolicy = 'change velocity, not star positions; no blank gap';
design.MarkerPolicy = 'UNDECIDED: configure independently of the phase schedule';
design.TimingMeaning = 'nominal seconds; compile to refreshes after measuring ifi';
design.ScheduleVersion = 'starfieldPhasePlan_v1';

validateattributes(design.InitialBlack_s, {'numeric'}, ...
    {'scalar','real','finite','positive'});
validateattributes(design.Stationary_s, {'numeric'}, ...
    {'scalar','real','finite','positive'});
validateattributes(design.Motion_s, {'numeric'}, ...
    {'scalar','real','finite','positive'});
validateattributes(design.Directions_deg, {'numeric'}, ...
    {'vector','real','finite','nonempty'});
validateattributes(design.Speeds_cm_s, {'numeric'}, ...
    {'vector','real','finite','positive','nonempty'});
validateattributes(design.Sequence, {'numeric'}, ...
    {'2d','ncols',2,'real','finite','integer','positive','nonempty'});
assert(all(design.Sequence(:,1) <= numel(design.Directions_deg)), ...
    'A direction index exceeds the length of Directions_deg.');
assert(all(design.Sequence(:,2) <= numel(design.Speeds_cm_s)), ...
    'A speed index exceeds the length of Speeds_cm_s.');
validateattributes(design.BlockRepeats, {'numeric'}, ...
    {'scalar','real','finite','integer','positive'});
validateattributes(design.Seed, {'numeric'}, ...
    {'scalar','real','finite','integer','>=',0,'<=',2^32-1});
assert(islogical(design.RandomizeWithinBlock) && ...
    isscalar(design.RandomizeWithinBlock), ...
    'RandomizeWithinBlock must be a logical scalar (true or false).');

% Use a reproducible order without changing the caller's random state.
previousRng = rng;
rngCleanup = onCleanup(@() rng(previousRng)); %#ok<NASGU>
rng(design.Seed, 'twister');

nPerBlock = size(design.Sequence,1);
nTrials = design.BlockRepeats*nPerBlock;
nPhases = 1 + 2*nTrials;

PhaseID = (1:nPhases)';
BlockID = zeros(nPhases,1);
TrialID = zeros(nPhases,1);
Mode = strings(nPhases,1);
Condition = strings(nPhases,1);
Duration_s = zeros(nPhases,1);
Heading_deg = nan(nPhases,1);        % Undefined for black/stationary phases.
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
        directionIndex = design.Sequence(sourceRow,1);
        speedIndex = design.Sequence(sourceRow,2);
        condition = string(sprintf('D%d_S%d',directionIndex,speedIndex));
        design.PresentedSequence(trial,:) = [directionIndex,speedIndex];

        % Preserve the stationary+movement PAIR when randomizing.
        row = row+1;
        BlockID(row) = block;
        TrialID(row) = trial;
        Mode(row) = "stationary";
        Condition(row) = condition;  % Names the upcoming movement condition.
        Duration_s(row) = design.Stationary_s;

        row = row+1;
        BlockID(row) = block;
        TrialID(row) = trial;
        Mode(row) = "move";
        Condition(row) = condition;
        Duration_s(row) = design.Motion_s;
        Heading_deg(row) = mod(design.Directions_deg(directionIndex),360);
        Speed_cm_s(row) = design.Speeds_cm_s(speedIndex);
    end
end

PlannedEnd_s = cumsum(Duration_s);
PlannedStart_s = [0; PlannedEnd_s(1:end-1)];
protocol = table(PhaseID,BlockID,TrialID,Mode,Condition,Duration_s, ...
    Heading_deg,Speed_cm_s,PlannedStart_s,PlannedEnd_s);

design.TotalNominalSeconds = PlannedEnd_s(end);
design.NumTrials = nTrials;
design.NumPhases = nPhases;

% Internal schedule-consistency checks (not display/hardware tests).
assert(row==nPhases && trial==nTrials, 'Incorrect phase/trial count.');
assert(all(protocol.PlannedStart_s(2:end)==protocol.PlannedEnd_s(1:end-1)), ...
    'The planned schedule contains a gap or overlap.');
assert(all(protocol.Speed_cm_s(protocol.Mode~="move")==0), ...
    'A nonmoving phase has nonzero speed.');

fprintf('\nPLAN ONLY: %d phases, %d movement trials, %d blocks.\n', ...
    nPhases,nTrials,design.BlockRepeats);
fprintf('Nominal duration: %.3f s (%.3f min).\n', ...
    design.TotalNominalSeconds,design.TotalNominalSeconds/60);
fprintf('No display or acquisition has started.\n\n');
disp(protocol);
end
