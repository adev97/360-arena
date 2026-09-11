function runLog = displayLinearSweep_360LED(trials, monitorInfo, arenaMap)
% DISPLAYLINEARSWEEP_360LED  Continuous, recycled dots on a 360 panorama.
%   log = displayLinearSweep_360LED(trials, monitorInfo, arenaMap)
%   log = displayLinearSweep_360LED(trials)  % legacy angular arena mapping
%   report = displayLinearSweep_360LED('selftest')  % no PTB/window needed
%
% Use with the matching CONTINUOUS master, not the old finite-cloud master.
% X is rightward, Y upward, Z along the selected Sweep Direction axis.
% Between resets: Z(t) = Z0 + Flow_Sign * displacement(t).
% +1: convergence at the selected direction; recycling there to the opposite
% direction. -1: expansion at the selected direction; reverse recycling.
%
% A dot's perpendicular distance b = hypot(X,Y) sets its depth half-span:
% B = b / tand(Recycle_Angle). Depth is wrapped to [-B,B). Therefore the dot
% disappears near a cone around the sink and reappears near the source.
% Uniform initial path phases prevent finite-cloud depletion in expectation.
% No fresh random draws are made per recycle. Radius/color remain fixed.
% Paths are constrained to fit vertically, including the maximum dot radius,
% so Num_Dots denotes visible dot identities (seam copies are the same dot).
% This is not a uniform-angle, uniform-solid-angle, or uniform-volume cloud.
%
% No trail rendering exists in this version. Each frame clears the background.
% The source/sink cone reset may be visible; it is not a continuous trajectory
% across the physical arena. Overshoot and multiple wraps are retained.
%
% Presentation is frame-indexed. Missed refreshes extend actual timing; logs
% flag them rather than claiming compensation. Escape is the only abort key.
% Blank/Interleave are unsupported. Validate mapping and timing on the rig.

if nargin == 1 && ischar(trials) && strcmp(trials, 'selftest')
    runLog = geometrySelfTest();
    return
end
if nargin < 2
    monitorInfo = getMonitorInformation();
end
if nargin < 3
    arenaMap.rect = [0, 0, round(360/monitorInfo.degPerPix), ...
        round(monitorInfo.screenSizeDegY/monitorInfo.degPerPix)];
    arenaMap.azimuthZeroXFraction = 0;
    arenaMap.azimuthSign = 1;
    arenaMap.verticalProjection = 'angular';
end

validateattributes(trials, {'struct'}, {'nonempty'});
validateattributes(monitorInfo.screenSizeDegY, {'numeric'}, ...
    {'scalar','real','finite','positive','<',180});
validateMap(arenaMap);
arenaMap.verticalFovDeg = monitorInfo.screenSizeDegY;

nTrials = numel(trials);
scene = cell(nTrials,1);
directionAzimuths = [0, -60, -120, 180, 120, 60];
runLog.model = 'periodic 3D dot translation / cone recycling / dots only';
runLog.aborted = false;
runLog.arenaMap = arenaMap;
runLog.frameColumns = {'Phase','ModelTime_s','VBL_s','StimulusOnset_s', ...
    'FlipCompleted_s','Missed_s','RequestedWhen_s','IntervalFromPreviousFlip_s', ...
    'RecycleEvents','VisibleDotCenters'};
runLog.phaseNames = {'Static','Sweep','Freeze','ITI'};
runLog.trial = repmat(struct('seed',[], 'scene',[], 'axisAzimuthDeg',[], ...
    'sourceAzimuthDeg',[], 'sinkAzimuthDeg',[], 'totalRecycles',0, ...
    'frameCounts',[], 'quantizedDurations_s',[], 'frames',[], ...
    'presentedFrames',0, 'completed',false), nTrials, 1);

% Prepare all random scenes before time-critical presentation. Each trial
% uses an independent stream; this does not modify MATLAB's global RNG.
for tr = 1:nTrials
    p = trials(tr);
    validateTrial(p);
    seed = p.Random_Seed + tr - 1;
    validateattributes(seed, {'numeric'}, ...
        {'scalar','integer','>=',0,'<=',2^32-1});
    travelAz = directionAzimuths(p.Sweep_Direction);
    scene{tr} = makeScene(p, arenaMap, travelAz, seed);
    runLog.trial(tr).seed = seed;
    runLog.trial(tr).scene = scene{tr};
    runLog.trial(tr).axisAzimuthDeg = travelAz;
    runLog.trial(tr).sinkAzimuthDeg = mod(travelAz + 180*(p.Flow_Sign < 0),360);
    runLog.trial(tr).sourceAzimuthDeg = mod(runLog.trial(tr).sinkAzimuthDeg+180,360);
end

AssertOpenGL;
oldPriority = Priority;
oldVerbosity = Screen('Preference','Verbosity',1);
oldDebugLevel = Screen('Preference','VisualDebuglevel',3);
w = [];
try
    screenNumber = monitorInfo.screenNumber;
    whitePix = WhiteIndex(screenNumber);
    blackPix = BlackIndex(screenNumber);
    grayPix = GammaCorrect((PixToLum(whitePix) + PixToLum(blackPix))/2);

    [w, windowRect] = Screen('OpenWindow',screenNumber,grayPix);
    [windowWidth, windowHeight] = Screen('WindowSize',w);
    runLog.windowRect = windowRect;
    validateViewport(arenaMap.rect, windowWidth, windowHeight);
    outsideRects = makeOutsideRects(arenaMap.rect,windowWidth,windowHeight);
    HideCursor;
    Priority(MaxPriority(w));
    KbName('UnifyKeyNames');
    escapeKey = KbName('ESCAPE');
    ifi = Screen('GetFlipInterval',w);
    runLog.ifi_s = ifi;

    % Build frame schedules and preallocate logs before initialization.
    schedules = cell(nTrials,1);
    for tr = 1:nTrials
        p = trials(tr);
        counts = round([p.Static_Duration,p.Sweep_Duration, ...
            p.Freeze_Duration,p.ITI]/ifi);
        counts(2:3) = max(counts(2:3),1);
        schedules{tr} = makeSchedule(counts,ifi);
        runLog.trial(tr).frameCounts = counts;
        runLog.trial(tr).quantizedDurations_s = counts*ifi;
        runLog.trial(tr).frames = nan(sum(counts),10);
    end
    stimInitScreen(w,trials(1).Initialization_Screen,grayPix,ifi);
    Screen('FillRect',w,grayPix);
    vbl = Screen('Flip',w);
    runLog.preTrialVBL_s = vbl;

    for tr = 1:nTrials
        p = trials(tr);                 % IMPORTANT: not trials(1)
        sc = scene{tr};
        schedule = schedules{tr};
        sweepTime = runLog.trial(tr).quantizedDurations_s(2);
        travelAz = runLog.trial(tr).axisAzimuthDeg;
        lastCycleIndex = zeros(p.Num_Dots,1);
        colorValues = blackPix*ones(1,p.Num_Dots);
        colorValues(sc.isWhite) = whitePix;
        if p.Dark_Background == 1
            backgroundPix = blackPix;
        else
            backgroundPix = grayPix;
        end
        for f = 1:size(schedule,1)
            phase = schedule(f,1);
            modelTime = schedule(f,2);
            recycleEvents = 0;
            visibleDotCenters = 0;
            Screen('FillRect',w,grayPix);
            if phase ~= 4
                Screen('FillRect',w,backgroundPix,arenaMap.rect);
                [cycleIndex,visibleDotCenters] = drawField( ...
                    w,sc,p,arenaMap,travelAz,modelTime,sweepTime,colorValues);
                recycleEvents = sum(abs(cycleIndex-lastCycleIndex));
                lastCycleIndex = cycleIndex;
                % Mask anything outside the calibrated arena viewport,
                % including seam copies. No unverified Screen subcommands.
                if ~isempty(outsideRects)
                    Screen('FillRect',w,grayPix,outsideRects);
                end
            end
            previousVBL = vbl;
            when = previousVBL + 0.5*ifi;
            [vbl,onset,flipTime,missed] = Screen('Flip',w,when);
            runLog.trial(tr).frames(f,:) = [phase,modelTime,vbl,onset, ...
                flipTime,missed,when,vbl-previousVBL,recycleEvents,visibleDotCenters];
            runLog.trial(tr).presentedFrames = f;
            [keyDown,~,keyCode] = KbCheck;
            if keyDown && keyCode(escapeKey)
                runLog.aborted = true;
                break
            end
        end
        n = runLog.trial(tr).presentedFrames;
        runLog.trial(tr).frames = runLog.trial(tr).frames(1:n,:);
        runLog.trial(tr).totalRecycles = sum(runLog.trial(tr).frames(:,9));
        runLog.trial(tr).completed = ~runLog.aborted;
        if runLog.aborted
            break
        end
    end
    % Explicitly terminate the last visible frame, including when ITI=0.
    Screen('FillRect',w,grayPix);
    runLog.finalGrayVBL_s = Screen('Flip',w,vbl+0.5*ifi);
    closeDisplay(w,oldPriority,oldVerbosity,oldDebugLevel);
catch ME
    closeDisplay(w,oldPriority,oldVerbosity,oldDebugLevel);
    rethrow(ME);
end

% Remove unused preallocation for trials that were never reached.
nMissed = 0;
nLong = 0;
for tr = 1:nTrials
    n = runLog.trial(tr).presentedFrames;
    runLog.trial(tr).frames = runLog.trial(tr).frames(1:n,:);
    nMissed = nMissed + sum(runLog.trial(tr).frames(:,6) > 0);
    nLong = nLong + sum(runLog.trial(tr).frames(:,8) > 1.5*ifi);
end
runLog.nDeadlineMisses = nMissed;
runLog.nLongFrameIntervals = nLong;
if nMissed > 0 || nLong > 0
    warning('Hyperspace:FrameTiming', ...
        ['Presentation had %d deadline flags and %d intervals >1.5 IFI. ' ...
         'Inspect the saved timestamps; intended speed/timing is not assured.'], ...
        nMissed,nLong);
end
end

function sc = makeScene(p,m,axisAz,seed)
% Construct a stationary-in-expectation ensemble on periodic 3D paths.
% Closest elevation describes a dot when crossing Z=0, its maximum absolute
% elevation. Keeping this below the calibrated vertical limit keeps it visible
% over the ENTIRE path instead of recycling unnoticed vertical-FOV exits.
s = RandStream('mt19937ar','Seed',seed);
n = p.Num_Dots;
W = m.rect(3)-m.rect(1);
H = m.rect(4)-m.rect(2);
pad = p.Dot_Size_Max+1;
assert(2*pad < H && 2*p.Dot_Size_Max < W, ...
    'Dot radii leave insufficient room in the calibrated arena viewport.');
if strcmp(m.verticalProjection,'angular')
    maxEl = m.verticalFovDeg*(0.5-pad/H);
else
    maxEl = atand((1-2*pad/H)*tand(m.verticalFovDeg/2));
end
b = p.Closest_Range_Min + ...
    (p.Closest_Range_Max-p.Closest_Range_Min)*rand(s,n,1);
peakEl = maxEl*(2*rand(s,n,1)-1);
side = 2*(rand(s,n,1) >= 0.5)-1;
sc.X = side.*b.*cosd(peakEl);
sc.Y = b.*sind(peakEl);
sc.depthHalfSpan = b/tand(p.Recycle_Angle);
sc.Z = sc.depthHalfSpan.*(2*rand(s,n,1)-1);
sc.radiusPix = p.Dot_Size_Min + ...
    (p.Dot_Size_Max-p.Dot_Size_Min)*rand(s,n,1);
sc.isWhite = rand(s,n,1) < 0.5;
if p.Dark_Background == 1
    sc.isWhite(:) = true;
end
sc.closestRange = b;
sc.peakElevationDeg = peakEl;
sc.initialAzimuthDeg = mod(atan2d(sc.X,sc.Z)+axisAz,360);
sc.initialElevationDeg = atan2d(sc.Y,hypot(sc.X,sc.Z));
sc.initialRange = sqrt(sc.X.^2+sc.Y.^2+sc.Z.^2);
end

function schedule = makeSchedule(counts,ifi)
% A sampled continuous trajectory: sweep samples start at t=0; the first
% freeze frame is at exactly t=T and therefore contains the exact endpoint.
% The first sweep sample equals the final static pose, as expected for
% motion that begins continuously. The first changed pose follows one IFI.
T = counts(2)*ifi;
schedule = [ ...
    [ones(counts(1),1), zeros(counts(1),1)]; ...
    [2*ones(counts(2),1), (0:counts(2)-1)'*ifi]; ...
    [3*ones(counts(3),1), T*ones(counts(3),1)]; ...
    [4*ones(counts(4),1), nan(counts(4),1)]];
end

function d = travelAtTime(t,p,T)
u = min(max(t/T,0),1);
d = p.Virtual_Travel*u.^p.Motion_Exponent;
end

function [Z,cycleIndex] = recycleDepth(sc,d,flowSign)
% Analytic modulo preserves overshoot and handles any number of recycles.
% The quotient also logs crossings without any per-frame random state.
% Depth intervals are half-open [-B,B). At the exact -B endpoint, negative
% flow recycles on the first sample strictly beyond that endpoint.
L = 2*sc.depthHalfSpan;
u = bsxfun(@plus,sc.Z+sc.depthHalfSpan,flowSign*reshape(d,1,[]));
cycleIndex = floor(bsxfun(@rdivide,u,L));
Z = bsxfun(@minus,bsxfun(@mod,u,L),sc.depthHalfSpan);
end

function [x,y,Z,cycleIndex] = projectScene(sc,d,m,axisAz,flowSign)
% Coordinates are LOCAL to the calibrated viewport: N dots x K times.
W = m.rect(3)-m.rect(1);
H = m.rect(4)-m.rect(2);
[Z,cycleIndex] = recycleDepth(sc,d,flowSign);
X = repmat(sc.X,1,numel(d));
Y = repmat(sc.Y,1,numel(d));
rho = hypot(X,Z);
az = atan2d(X,Z)+axisAz;
x = W*mod(m.azimuthZeroXFraction+m.azimuthSign*az/360,1);
if strcmp(m.verticalProjection,'angular')
    el = atan2d(Y,rho);
    y = H*(0.5-el/m.verticalFovDeg);
else
    y = (H/2)*(1-(Y./rho)/tand(m.verticalFovDeg/2));
end
end

function [cycleIndex,nVisible] = drawField(w,sc,p,m,axisAz,t,T,colors)
% Moving dot heads ONLY. No history samples or line-drawing calls.
W = m.rect(3)-m.rect(1);
H = m.rect(4)-m.rect(2);
d = travelAtTime(t,p,T);
[x,y,~,cycleIndex] = projectScene(sc,d,m,axisAz,p.Flow_Sign);
x = x'; y = y';
nVisible = sum(isfinite(x) & isfinite(y) & x >= 0 & x < W & y >= 0 & y < H);
r = sc.radiusPix';
base = [x-r; y-r; x+r; y+r];
% Draw seam copies so a dot straddling azimuth 0/360 is not cut in half.
rects = [bsxfun(@plus,base,[-W;0;-W;0]),base, ...
    bsxfun(@plus,base,[W;0;W;0])];
c = repmat(colors,1,3);
keep = all(isfinite(rects),1) & rects(3,:) > 0 & rects(1,:) < W & ...
    rects(4,:) > 0 & rects(2,:) < H;
rects = bsxfun(@plus,rects(:,keep),m.rect([1,2,1,2])');
if ~isempty(rects)
    Screen('FillOval',w,repmat(c(keep),3,1),rects,2*p.Dot_Size_Max);
end
end

function validateTrial(p)
nonnegative = {'Virtual_Travel','Static_Duration','ITI','Initialization_Screen'};
positive = {'Closest_Range_Min','Closest_Range_Max','Dot_Size_Min', ...
    'Dot_Size_Max','Sweep_Duration','Freeze_Duration'};
for j = 1:numel(nonnegative)
    validateattributes(p.(nonnegative{j}),{'numeric'}, ...
        {'scalar','real','finite','nonnegative'},mfilename,nonnegative{j});
end
for j = 1:numel(positive)
    validateattributes(p.(positive{j}),{'numeric'}, ...
        {'scalar','real','finite','positive'},mfilename,positive{j});
end
validateattributes(p.Num_Dots,{'numeric'},{'scalar','integer','positive'});
validateattributes(p.Sweep_Direction,{'numeric'}, ...
    {'scalar','integer','>=',1,'<=',6});
validateattributes(p.Motion_Exponent,{'numeric'}, ...
    {'scalar','real','finite','>=',1});
validateattributes(p.Random_Seed,{'numeric'}, ...
    {'scalar','integer','>=',0,'<=',2^32-1});
validateattributes(p.Dark_Background,{'numeric','logical'}, ...
    {'scalar','binary'});
validateattributes(p.Recycle_Angle,{'numeric'}, ...
    {'scalar','real','finite','>',0,'<',90});
validateattributes(p.Flow_Sign,{'numeric'}, ...
    {'scalar','real','finite','integer'});
assert(any(p.Flow_Sign == [-1,1]),'Flow Sign must be +1 or -1.');
assert(p.Closest_Range_Max >= p.Closest_Range_Min, ...
    'Closest Range Max must be >= Closest Range Min.');
assert(p.Dot_Size_Max >= p.Dot_Size_Min,'Dot Size Max must be >= Dot Size Min.');
assert(p.Blank == 0 && p.Interleave == 0, ...
    'This renderer requires Blank=0 and Interleave=0.');
end

function validateMap(m)
validateattributes(m.rect,{'numeric'},{'row','numel',4,'real','finite'});
assert(m.rect(3) > m.rect(1) && m.rect(4) > m.rect(2), ...
    'arenaMap.rect must have positive width and height.');
validateattributes(m.azimuthZeroXFraction,{'numeric'}, ...
    {'scalar','real','finite','>=',0,'<',1});
assert(isscalar(m.azimuthSign) && any(m.azimuthSign == [-1,1]), ...
    'arenaMap.azimuthSign must be +1 or -1.');
assert(ischar(m.verticalProjection) && ...
    any(strcmp(m.verticalProjection,{'angular','cylindrical'})), ...
    'verticalProjection must be ''angular'' or ''cylindrical''.');
end

function validateViewport(r,W,H)
assert(r(1) >= 0 && r(2) >= 0 && r(3) <= W && r(4) <= H, ...
    ['Calibrated arena rect [%g %g %g %g] does not fit the %g x %g window. ' ...
     'Check degPerPix, vertical FOV, and arenaMap.rect; no automatic stretch.'], ...
     r(1),r(2),r(3),r(4),W,H);
end

function rects = makeOutsideRects(r,W,H)
rects = [0,0,r(1),H; r(3),0,W,H; ...
    r(1),0,r(3),r(2); r(1),r(4),r(3),H]';
rects = rects(:,rects(3,:) > rects(1,:) & rects(4,:) > rects(2,:));
end

function closeDisplay(w,oldPriority,oldVerbosity,oldDebugLevel)
Priority(oldPriority);
if ~isempty(w)
    Screen('Close',w);
end
ShowCursor;
Screen('Preference','Verbosity',oldVerbosity);
Screen('Preference','VisualDebuglevel',oldDebugLevel);
end

function report = geometrySelfTest()
% Exercises the ACTUAL helpers used for presentation. No PTB calls.
% Does not test PTB, luminance calibration, physical mapping, or timing.
checks = {};
m.rect = [0,0,3600,900];
m.azimuthZeroXFraction = 0;
m.azimuthSign = 1;
m.verticalProjection = 'angular';
m.verticalFovDeg = 90;
sc.X = [1;-1;0;1]; sc.Y = [0;0;1;0]; sc.Z = [5;5;5;-5];
sc.depthHalfSpan = 100*ones(4,1);
[x,y] = projectScene(sc,[0,1],m,0,1);
dx = mod(x(:,2)-x(:,1)+1800,3600)-1800;
assert(dx(1) < 0 && dx(2) > 0,'Front convergence failed.');
assert(y(3,2) > y(3,1),'Vertical front convergence failed.');
assert(abs(x(4,2)-1800) > abs(x(4,1)-1800),'Rear expansion failed.');
checks{end+1} = 'requested back-to-front flow';
[xf,yf] = projectScene(sc,[0,1],m,0,-1);
dxf = mod(xf(:,2)-xf(:,1)+1800,3600)-1800;
assert(dxf(1) > 0 && dxf(2) < 0 && yf(3,2) < yf(3,1));
assert(abs(xf(4,2)-1800) < abs(xf(4,1)-1800));
checks{end+1} = 'reverse flow matches prior expansion sign';
for a = [0,-60,-120,180,120,60]
    xr = projectScene(sc,[0,1],m,a,1);
    err = mod((xr-x)/10-a+180,360)-180;
    assert(max(abs(err(:))) < 1e-10,'Direction rotation failed.');
end
checks{end+1} = 'six direction axes';
c.Z = 9; c.depthHalfSpan = 10;
[z,q] = recycleDepth(c,[0,2,42],1);
assert(isequal(z,[9,-9,-9]) && isequal(q,[0,1,3]));
c.Z = -9;
[z,q] = recycleDepth(c,[0,2,42],-1);
assert(isequal(z,[-9,9,9]) && isequal(q,[0,-1,-3]));
checks{end+1} = 'overshoot and multiple recycles in both directions';
c.Z = 9;
assert(recycleDepth(c,1,1) == -10,'Positive endpoint convention failed.');
checks{end+1} = 'half-open depth boundary';
p.Virtual_Travel = 50; p.Motion_Exponent = 2;
assert(isequal(travelAtTime([-1,0,1,2,3],p,2),[0,0,12.5,50,50]));
sched = makeSchedule([2,3,2,1],0.01);
assert(isequal(sched(:,1)',[1,1,2,2,2,3,3,4]));
assert(sched(3,2) == 0 && abs(sched(6,2)-0.03) < 1e-12);
checks{end+1} = 'travel endpoint and phase schedule';
p.Num_Dots = 300;
p.Closest_Range_Min = 20; p.Closest_Range_Max = 100;
p.Recycle_Angle = 10; p.Dot_Size_Min = 1; p.Dot_Size_Max = 2;
p.Dark_Background = 1;
for projection = {'angular','cylindrical'}
    m.verticalProjection = projection{1};
    s = makeScene(p,m,0,7);
    s2 = makeScene(p,m,0,7);
    assert(isequal(s,s2),'Random seed reproducibility failed.');
    for flowSign = [-1,1]
        [xx,yy,zz,qq] = projectScene(s,linspace(0,1e5,1001),m,0,flowSign);
        assert(all(isfinite(xx(:))) && all(isfinite(yy(:))));
        assert(all(xx(:) >= 0 & xx(:) < 3600));
        assert(all(yy(:) >= p.Dot_Size_Max & yy(:) <= 900-p.Dot_Size_Max));
        assert(all(all(bsxfun(@ge,zz,-s.depthHalfSpan))));
        assert(all(all(bsxfun(@lt,zz,s.depthHalfSpan))));
        assert(all(all(flowSign*diff(qq,1,2) >= 0)));
    end
end
checks{end+1} = 'all dot centers visible through long runs in both projections';
checks{end+1} = 'deterministic seeds and monotonic recycle counts';
b = hypot(s.X,s.Y);
cone = atan2d(b,s.depthHalfSpan);
assert(max(abs(cone-p.Recycle_Angle)) < 1e-10);
checks{end+1} = 'recycle cone geometry';
xHold = projectScene(s,travelAtTime([2,3,4],p,2),m,0,1);
assert(isequal(xHold(:,1),xHold(:,2)) && isequal(xHold(:,1),xHold(:,3)));
checks{end+1} = 'freeze does not continue recycling';
% A grid of uniform phases translates into another uniform grid on the
% same periodic path; it cannot drain out of the back over repeated cycles.
c.depthHalfSpan = 10*ones(1000,1);
c.Z = -10+((0:999)'+0.5)*20/1000;
z0 = recycleDepth(c,0,1);
z1 = recycleDepth(c,17*20/1000,1);
assert(max(abs(sort(z0)-sort(z1))) < 1e-10);
checks{end+1} = 'uniform path phases do not deplete';
assert(abs((mod((2-3598)+1800,3600)-1800)-4) < 1e-12);
checks{end+1} = 'azimuth seam arithmetic';
report.passed = true;
report.checks = checks;
report.nCheckGroups = numel(checks);
report.hardwareTested = false;
fprintf('Continuous-dot self-test passed (%d groups). Hardware not tested.\n', ...
    report.nCheckGroups);
end
