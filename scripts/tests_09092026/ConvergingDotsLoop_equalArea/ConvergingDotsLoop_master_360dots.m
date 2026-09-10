function [trials, meta] = ConvergingDotsLoop_master_360dots(savename)
% CONVERGINGDOTSLOOP_MASTER_360DOTS
% Point-converging, endlessly recycled dots with uniform EXPECTED dot-center
% density in the displayed azimuth/elevation rectangle.
%
% This is a DIFFERENT motion model from the old constant-cm/s stimulus.
% Convergence_Speed is now the MEAN decrease in angular distance to the
% target, in deg/s: one back-to-front traversal takes 180/speed seconds.
% Instantaneous angular speed is NOT constant.
%
% Pipeline remains: monitor information -> your existing trial builder ->
% display -> your existing save helper. Replace master AND display together.
%
% Additional required file: convergingDotsEqualAreaPosition.m

monitorInfo = getMonitorInformation();
R_arena = monitorInfo.radius;

table = { ...
    'Num Dots',                    600,          [], []; ...
    'Depth Min (cm)',              2*R_arena,    [], []; ... % radius, not diameter
    'Depth Max (cm)',              3*R_arena,    [], []; ... % radius, not diameter
    'Dot Size Min (px)',           6,            [], []; ...
    'Dot Size Max (px)',           12,           [], []; ...
    'Convergence Speed (degps)',   30,           [], []; ... % MEAN rate; 30 -> 6-s loop
    'Timing (delay,duration,wait)', 0,            20, 3; ...
    'Blank',                       0,            [], []; ...
    'Randomize',                   0,            [], []; ...
    'Interleave',                  0,            [], []; ...
    'Repeats',                     1,            [], []; ...
    'Initialization Screen (s)',   5,            [], []};

% No Arrival Radius: there is no deliberately excluded region near the target.
% No entry-angle jitter: randomly choose a new PATH at the same back source.

stimType = 'Converging Dots Loop';
user = 'AD';
tag = 'm001';
iftest = 1;

rngBeforeTrialBuilder = rng;
trials = trialStruct_RFmapFast_AD(stimType, table);

% Explicit markers prevent interpreting an old cm/s trials struct as deg/s.
for k = 1:numel(trials)
    trials(k).Flow_Model = 'equalAreaPointFlow_v1';
    trials(k).Speed_Units = 'mean_deg_per_s';
end

meta.monitorInfo = monitorInfo;
meta.user = user;
meta.tag = tag;
meta.stimType = stimType;
meta.stimulusTable = table;
meta.flowModel = 'equalAreaPointFlow_v1';
meta.speedMeaning = 'Mean angular-distance decrease; loop seconds = 180/Convergence_Speed';
meta.uniformity = 'Uniform expected DOT-CENTER density in display pixels, not uniform 3-D volume';
meta.worldMeaning = ['Optional curved 3-D embedding in a spherical radial shell; ', ...
    'depth does not determine retinal motion or dot size in this model'];
meta.rngBeforeTrialBuilder = rngBeforeTrialBuilder;
nowTime = datetime('now');
meta.dateStr = char(datetime(nowTime, 'Format', 'yyyyMMdd'));
meta.timestamp = char(datetime(nowTime, 'Format', 'yyyy-MM-dd HH:mm:ss'));
meta.matlabVersion = version;

meta.displayLog = displayConvergingDotsLoop_360LED(trials);

if nargin < 1 || isempty(savename)
    savename = 'ConvergingDotsLoop_equalArea_600';
end
trialStructSave_360(trials, meta, savename, tag, iftest);
end
