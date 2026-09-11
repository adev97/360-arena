function [runLog, caughtError] = displayHyperSpace_360LED(protocol,p,m,options)
% DISPLAYHYPERSPACE_360LED One persistent world across all protocol phases.
% Called by HyperSpace_master_360dots. Do not discard the second output:
% the master saves a returned partial log, then rethrows caughtError.
%
% PHOTODIODE OPTION 1: draw LeftBoxStim_small at a constant brightness within
% each phase. Toggle on the SAME flip that starts the next phase. No per-frame
% flicker. Initial black has no optical onset edge; phase 2 is the first edge.
% On completion (or ESC), hide stars and invert the last phase's patch once
% for an optical offset. Hold it briefly, then explicitly return to black.
% Those finalization events are logged OUTSIDE the experimental phase table.
%
% Stationary phases reuse the current projected image exactly. A moving
% phase's first frame advances one refresh at its new velocity. No scene
% rotation, per-trial initialization, implicit ITI, or initialization screen.
% No photodiode voltage acquisition or OneBox control is performed here.
% Timestamp mode is not changed; SkipSyncTests must remain zero.

runLog = struct();
caughtError = [];
world = []; cachedFrame = []; raw = []; resetEvents = {};
phaseWorldStart = {}; phaseWorldEnd = {}; phaseRngStart = {};
F = 0; k = 0; nPhases = height(protocol);
runLog.name = 'HyperSpace';
runLog.model = 'HyperSpace_persistentTranslation_v1';
runLog.status = 'initializing';
runLog.aborted = false;
runLog.hardwareValidated = false;
runLog.error = [];
runLog.terminal = [];
runLog.cleanupBlack = [];
runLog.photodiodeMeaning = ['Commanded phase-constant patch values, NOT measured ', ...
    'voltage. Initial black is optically unmarked. Phase boundaries toggle. ', ...
    'Terminal/cleanup events are outside the protocol.'];
phases = protocol;
phases.QuantizedDuration_s = nan(nPhases,1);
phases.QuantizedStart_s = nan(nPhases,1);
phases.OnsetVBL_s = nan(nPhases,1);
phases.OnsetPTB_s = nan(nPhases,1);
phases.OffsetVBL_s = nan(nPhases,1);
phases.OffsetPTB_s = nan(nPhases,1);
phases.ActualDuration_s = nan(nPhases,1);
phases.FirstGlobalFrame = nan(nPhases,1);
phases.LastGlobalFrame = nan(nPhases,1);
phases.NumRenderedFrames = zeros(nPhases,1);
phases.NumSkippedLogicalFrames = zeros(nPhases,1);
phases.Completed = false(nPhases,1);
phases.OpticalOnsetEdgeExpected = [false;true(nPhases-1,1)];
frameNames = {'GlobalFrameID','PhaseID','TrialID','BlockID','PhaseFrameIndex', ...
    'ModelAdvance_s','CumulativeMotionTime_s','RequestedFlipTime_s','VBLTime_s', ...
    'OnsetPTB_s','FlipCompleted_s','Missed_s','PhotodiodeValue','VisibleCount', ...
    'DrawnCount','ResetCount','SkippedLogicalFrames'};
window = []; restoreScreen = [];
try
    assert(exist('LeftBoxStim_small','file')==2, ...
        'HyperSpace:MissingMarker','LeftBoxStim_small.m must be on the MATLAB path.');
    c = HyperSpaceWorld('validate',p,m);
    runLog.rngBeforeWorld = rng;
    world = HyperSpaceWorld('init',p,m);
    runLog.initialWorld = world;
    runLog.rngAfterWorldInit = rng;
    cachedFrame = HyperSpaceWorld('project',world);
    phaseWorldStart = cell(nPhases,1); phaseWorldEnd = cell(nPhases,1);
    phaseRngStart = cell(nPhases,1);
    AssertOpenGL;
    assert(Screen('Preference','SkipSyncTests')==0, ...
        'HyperSpace:SyncTestsDisabled', ...
        'SkipSyncTests must be zero. Resolve timing failures rather than bypassing them.');
    oldPriority = Priority;
    oldVerbosity = Screen('Preference','Verbosity',3);
    oldVisualDebug = Screen('Preference','VisualDebuglevel',3);
    restoreScreen = onCleanup(@() localCleanup(oldPriority,oldVerbosity,oldVisualDebug));
    KbName('UnifyKeyNames'); escapeKey = KbName('ESCAPE');
    whitePix = WhiteIndex(m.screenNumber); blackPix = BlackIndex(m.screenNumber);
    cal = localCalibration(blackPix,whitePix,c.Dark_Background);
    [window,rect] = Screen('OpenWindow',m.screenNumber,blackPix);
    W = RectWidth(rect); H = RectHeight(rect);
    assert(W==m.screenSizePixX && H==m.screenSizePixY, ...
        'HyperSpace:DisplaySize', ...
        'Window is %gx%g; monitorInfo requires %gx%g. Fix the display mode.', ...
        W,H,m.screenSizePixX,m.screenSizePixY);
    Screen('ColorRange',window,whitePix);
    Screen('BlendFunction',window,'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA');
    HideCursor;
    ifi = Screen('GetFlipInterval',window);
    plan = HyperSpaceFrameClock('compile',protocol,ifi);
    phases.QuantizedDuration_s = plan.duration;
    phases.QuantizedStart_s = [0;cumsum(plan.duration(1:end-1))];
    runLog.ifiSeconds = ifi;
    runLog.quantizedTotalSeconds = sum(plan.duration);
    runLog.screenRect = rect; runLog.calibration = cal;
    runLog.timestampModeBefore = Screen('Preference','VBLTimestampingMode');
    runLog.conserveVRAMFlags = Screen('Preference','ConserveVRAM');
    raw = nan(plan.maxFrames,numel(frameNames));
    resetEvents = cell(plan.maxFrames,1);
    % Compile drawing shader before the experimental clock starts.
    Screen('DrawDots',window,[W/2,W/2+20;H/2,H/2], ...
        [c.Dot_Size_Min,c.Dot_Size_Max],blackPix,[],3);
    Screen('FillRect',window,blackPix);
    LeftBoxStim_small(window,rect,blackPix);
    vbl = Screen('Flip',window);
    runLog.preProtocolBlackVBL_s = vbl;
    Priority(MaxPriority(window));
    runLog.status = 'running';
    lastMarker = 0;
    stopRequested = false;
    nStarted = 0;
    for k = 1:nPhases
        if localEscape(escapeKey)
            stopRequested = true;
            break
        end
        phaseWorldStart{k} = world;
        phaseRngStart{k} = rng;
        firstVBL = NaN;
        previousSlot = -1;
        slot = 0;
        while slot < plan.frames(k)
            modelDt = 0; events = zeros(6,0);
            if plan.isMoving(k)
                modelDt = (slot-previousSlot)*ifi;
                [world,events] = HyperSpaceWorld('advance',world,plan.velocity(:,k),modelDt);
                cachedFrame = HyperSpaceWorld('project',world);
            end
            bg = cal.backgroundPix;
            if plan.isBlack(k), bg = blackPix; end
            Screen('FillRect',window,bg);
            nDrawn = 0; nVisible = 0;
            if ~plan.isBlack(k)
                nDrawn = localDrawWrapped(window,cachedFrame,cal,W,whitePix);
                nVisible = cachedFrame.nVisible;
            end
            marker = plan.marker(k);
            localMarker(window,rect,marker,whitePix,blackPix);
            requested = vbl+0.5*ifi;
            [vbl,onset,finished,missed] = Screen('Flip',window,requested);
            F = F+1;
            skipped = max(0,slot-previousSlot-1);
            raw(F,:) = [F,k,protocol.TrialID(k),protocol.BlockID(k),slot+1, ...
                modelDt,world.totalAdvanceSeconds,requested,vbl,onset,finished, ...
                missed,marker,nVisible,nDrawn,size(events,2),skipped];
            if options.RecordResetEvents, resetEvents{F} = events; end
            if previousSlot<0
                firstVBL = vbl;
                nStarted = k;
                phases.OnsetVBL_s(k) = vbl;
                phases.OnsetPTB_s(k) = onset;
                phases.FirstGlobalFrame(k) = F;
                if k>1
                    phases.OffsetVBL_s(k-1) = vbl;
                    phases.OffsetPTB_s(k-1) = onset;
                    phases.ActualDuration_s(k-1) = onset-phases.OnsetPTB_s(k-1);
                    phases.Completed(k-1) = true;
                end
            end
            phases.LastGlobalFrame(k) = F;
            phases.NumRenderedFrames(k) = phases.NumRenderedFrames(k)+1;
            phases.NumSkippedLogicalFrames(k) = phases.NumSkippedLogicalFrames(k)+skipped;
            previousSlot = slot;
            lastMarker = marker;
            if localEscape(escapeKey)
                stopRequested = true;
                break
            end
            slot = HyperSpaceFrameClock('next',previousSlot,vbl,firstVBL,ifi);
        end
        phaseWorldEnd{k} = world;
        if stopRequested, break; end
    end
    runLog.aborted = stopRequested;
    % Guaranteed commanded inversion from the last displayed phase. This
    % marks completion/abort, NOT a new experimental condition.
    if F>0
        terminalMarker = 1-lastMarker;
        Screen('FillRect',window,blackPix);
        localMarker(window,rect,terminalMarker,whitePix,blackPix);
        [vbl,onset,finished,missed] = Screen('Flip',window,vbl+0.5*ifi);
        runLog.terminal = localEvent('terminal',nStarted,terminalMarker,vbl,onset,finished,missed);
        phases.OffsetVBL_s(nStarted) = vbl;
        phases.OffsetPTB_s(nStarted) = onset;
        phases.ActualDuration_s(nStarted) = onset-phases.OnsetPTB_s(nStarted);
        phases.Completed(nStarted) = ~stopRequested && nStarted==nPhases;
        % No repeated flips are necessary while this static patch is held.
        holdFrames = max(1,round(options.TerminalMarkerHold_s/ifi));
        Screen('FillRect',window,blackPix);
        localMarker(window,rect,0,whitePix,blackPix);
        [vbl,onset,finished,missed] = Screen('Flip',window,vbl+(holdFrames-0.5)*ifi);
        runLog.cleanupBlack = localEvent('cleanup_black',nStarted,0,vbl,onset,finished,missed);
        WaitSecs(options.CleanupBlackHold_s);
    end
    if stopRequested, runLog.status = 'aborted'; else, runLog.status = 'completed'; end
    runLog.timestampModeAfter = Screen('Preference','VBLTimestampingMode');
catch ME
    caughtError = ME;
    runLog.status = 'error';
    runLog.error = struct('identifier',ME.identifier,'message',ME.message, ...
        'stack',ME.stack,'report',getReport(ME,'extended','hyperlinks','off'));
    % No fabricated offset timestamp if the drawing system failed.
end
% Cleanup happens before conversion/saving. The master receives all known
% frames, even after ESC or a caught error, and must rethrow the error.
clear restoreScreen
runLog.phases = phases;
if isempty(raw)
    runLog.frames = array2table(zeros(0,numel(frameNames)),'VariableNames',frameNames);
else
    runLog.frames = array2table(raw(1:F,:),'VariableNames',frameNames);
end
runLog.resetEvents = resetEvents(1:F);
runLog.resetEventColumns = {'PoolID','StepOffset_s','EntryX_cm','EntryY_cm','EntryZ_cm','Generation'};
runLog.phaseWorldStart = phaseWorldStart;
runLog.phaseWorldEnd = phaseWorldEnd;
runLog.phaseRngStart = phaseRngStart;
runLog.finalWorld = world;
runLog.rngAfterPresentation = rng;
runLog.nFrames = F;
runLog.nPhasesStarted = sum(isfinite(phases.OnsetPTB_s));
runLog.nPositiveMissedFlags = sum(runLog.frames.Missed_s>0);
runLog.nLongFrameIntervals = 0;
if isfield(runLog,'ifiSeconds')
    runLog.nLongFrameIntervals = sum(diff(runLog.frames.VBLTime_s)>1.5*runLog.ifiSeconds);
end
runLog.timeBase = 'PTB system seconds, not OneBox/ADC seconds';
runLog.motionTimingPolicy = ['First moving frame steps one ifi at the new velocity; ', ...
    'later motion catches up on a refresh-quantized grid after late flips. ', ...
    'Stationary starts with the exact last drawn world state.'];
end

function e = localEvent(kind,afterPhase,value,vbl,onset,finished,missed)
e = struct('Kind',kind,'AfterPhaseID',afterPhase,'PhotodiodeValue',value, ...
    'VBLTime_s',vbl,'OnsetPTB_s',onset,'FlipCompleted_s',finished,'Missed_s',missed);
end

function localMarker(w,rect,value,whitePix,blackPix)
color = blackPix;
if value==1, color = whitePix; end
LeftBoxStim_small(w,rect,color);
end

function n = localDrawWrapped(w,f,cal,W,whitePix)
if isempty(f.xPix), n = 0; return; end
index = 1+round(f.visibleContrast*(numel(cal.whiteLUT)-1));
color = cal.whiteLUT(index);
negative = f.polarity<0;
color(negative) = cal.blackLUT(index(negative));
keep = abs(color-cal.backgroundPix)>1e-12;
n = sum(keep);
if n==0, return; end
x = f.xPix(keep); y = f.yPix(keep); d = f.diameterPx(keep);
color = color(keep); strength = f.visibleContrast(keep);
[~,order] = sort(strength);
x = x(order); y = y(order); d = d(order); color = color(order);
left = find(x-d/2-1<0); right = find(x+d/2+1>W);
xy = [x,x(left)+W,x(right)-W;y,y(left),y(right)];
sizes = [d,d(left),d(right)];
values = [color,color(left),color(right)];
rgba = [repmat(values,3,1);whitePix*ones(1,numel(values))];
Screen('DrawDots',w,xy,sizes,rgba,[],3);
end

function cal = localCalibration(blackPix,whitePix,dark)
blackLum = PixToLum(blackPix); whiteLum = PixToLum(whitePix);
assert(isscalar(blackLum) && isscalar(whiteLum) && isfinite(blackLum) && ...
    isfinite(whiteLum) && whiteLum>blackLum,'Invalid luminance calibration.');
a = linspace(0,1,2049);
bgLum = (blackLum+whiteLum)/2;
if dark, bgLum = blackLum; end
cal.backgroundLum = bgLum;
cal.backgroundPix = GammaCorrect(bgLum);
cal.whiteLUT = arrayfun(@GammaCorrect,bgLum+a*(whiteLum-bgLum));
cal.blackLUT = arrayfun(@GammaCorrect,bgLum+a*(blackLum-bgLum));
values = [cal.backgroundPix,cal.whiteLUT,cal.blackLUT];
assert(all(isfinite(values)) && all(values>=blackPix-1e-6) && all(values<=whitePix+1e-6), ...
    'GammaCorrect output is outside the native pixel range.');
end

function yes = localEscape(key)
[down,~,keys] = KbCheck;
yes = down && any(keys(key));
end

function localCleanup(oldPriority,oldVerbosity,oldVisualDebug)
Priority(oldPriority);
Screen('CloseAll');
ShowCursor;
Screen('Preference','Verbosity',oldVerbosity);
Screen('Preference','VisualDebuglevel',oldVisualDebug);
end
