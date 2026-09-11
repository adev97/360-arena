function runLog = displayStarfieldFlow_360LED(trials,monitorInfo)
% DISPLAYSTARFIELDFLOW_360LED Render full 3-D translational optic flow.
% Uses existing PixToLum, GammaCorrect, stimInitScreen, LeftBoxStim_small,
% and Psychtoolbox. Does NOT disable synchronization tests. ESC aborts;
% errors are rethrown by MATLAB after onCleanup restores the screen/cursor/
% priority/preferences.
%
% DrawDots type 3 supplies shader-based round anti-aliased dots. Contrast
% fades are converted with the lab's luminance calibration BEFORE drawing;
% OpenGL blending supplies edge antialiasing, not the depth-fade law. Gamma
% correctness of blended edge/overlap pixels still depends on the rig's
% framebuffer/LUT configuration. No new physical LED calibration is implied.
%
% Frames use elapsed seconds predicted for the next retrace. A missed flip
% causes catch-up on the following frame, not slow-motion integration. The
% already-presented late frame cannot be corrected. Predicted model times,
% actual timestamps, deadline flags, counts and hidden resets are saved.
%
% PHOTODIODE (Option B, per-frame): LeftBoxStim_small draws a small box in
% the corner defined by its own FillRect coordinates (see that file). The
% box toggles white/black on EVERY logged flip -- delay frames, stimulus
% frames, the stimulus-offset flip, and ITI frames -- using ONE toggle that
% persists across the entire run, not reset per trial. This produces a
% continuous square wave for the whole session: a plateau longer than one
% ifi in the physically-recorded diode trace, compared against this file's
% saved frameOnsetTimes/flipMissedSeconds, is how a dropped frame is caught
% independently of PTB's own self-reported miss flag.

if nargin<2
    monitorInfo = getMonitorInformation();
end
m = monitorInfo;
assert(isstruct(trials) && ~isempty(trials),'trials must be a nonempty struct array.');
assert(isfield(trials,'Flow_Model') && isfield(trials,'Speed_Units'), ...
    'Use StarfieldFlow_master_360dots; old convergence trials are incompatible.');
assert(isfield(trials,'Initialization_Screen') && ...
    isscalar(trials(1).Initialization_Screen) && ...
    isfinite(trials(1).Initialization_Screen) && trials(1).Initialization_Screen>=0, ...
    'Initialization_Screen must be finite and nonnegative.');
assert(exist('LeftBoxStim_small','file')==2, ...
    'LeftBoxStim_small.m must be on the MATLAB path for photodiode instrumentation.');

% Validate and initialize all worlds before timed presentation begins.
states = cell(1,numel(trials));
configs = cell(size(states));
for k = 1:numel(trials)
    tr = trials(k);
    assert(strcmp(tr.Flow_Model,'starfieldTranslation_v1') && ...
        strcmp(tr.Speed_Units,'cm_per_s'), ...
        'Wrong motion model or units; regenerate trials with the new master.');
    assert(isnumeric(tr.Timing) && numel(tr.Timing)==3 && ...
        all(isfinite(tr.Timing(:))) && all(tr.Timing(:)>=0), ...
        'Timing must be [delay duration wait] in nonnegative seconds.');
    configs{k} = starfieldFlow360('validate',tr,m);
    if ~strcmp(tr.Stimulus_Type,'Blank')
        states{k} = starfieldFlow360('init',tr,m);
    end
end

AssertOpenGL;
oldPriority = Priority;
oldVerbosity = Screen('Preference','Verbosity',3);
oldVisualDebug = Screen('Preference','VisualDebuglevel',3);
cleanupObj = onCleanup(@() localCleanup(oldPriority,oldVerbosity,oldVisualDebug)); %#ok<NASGU>
assert(Screen('Preference','SkipSyncTests')==0, ...
    ['Psychtoolbox SkipSyncTests is enabled. Restore it to 0 and resolve ', ...
     'timing-test failures before using this stimulus.']);
KbName('UnifyKeyNames');
escapeKey = KbName('ESCAPE');
whitePix = WhiteIndex(m.screenNumber);
blackPix = BlackIndex(m.screenNumber);
calibration = localCalibration(blackPix,whitePix);
firstCal = calibration(configs{1}.Dark_Background+1);
[w,rect] = Screen('OpenWindow',m.screenNumber,firstCal.backgroundPix);
W = RectWidth(rect);
H = RectHeight(rect);
assert(W==m.screenSizePixX && H==m.screenSizePixY, ...
    'Window is %gx%g; monitorInfo specifies %gx%g. Fix the display mode.', ...
    W,H,m.screenSizePixX,m.screenSizePixY);
Screen('ColorRange',w,whitePix);
Screen('BlendFunction',w,'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA');
HideCursor;
ifi = Screen('GetFlipInterval',w);
assert(isfinite(ifi) && ifi>0,'Invalid measured refresh interval.');
% Force first-use shader compilation / size validation before the stimulus.
for k = 1:numel(configs)
    c = configs{k};
    Screen('DrawDots',w,[W/2,W/2+20;H/2,H/2], ...
        [c.Dot_Size_Min,c.Dot_Size_Max],firstCal.backgroundPix,[],3);
end
Screen('FillRect',w,firstCal.backgroundPix);
Screen('Flip',w);
Priority(MaxPriority(w));
stimInitScreen(w,trials(1).Initialization_Screen,firstCal.backgroundPix,ifi);
Screen('FillRect',w,firstCal.backgroundPix);
vbl = Screen('Flip',w);

runLog = struct();
runLog.model = 'starfieldTranslation_v1';
runLog.ifiSeconds = ifi;
runLog.screenRect = rect;
runLog.dotType = 3;
runLog.calibration = calibration;
runLog.rngBeforePresentation = rng;
runLog.trials = cell(1,numel(trials));
runLog.aborted = false;
runLog.hardwareValidated = false; % NOT set true just because code executes
runLog.startVbl = vbl;
runLog.photodiodeInstrumented = true;
runLog.photodiodeMeaning = ['Toggle persists across the entire run (not reset per ', ...
    'trial); every logged flip -- delay, stimulus, offset, ITI -- carries one ', ...
    'toggle value, giving a continuous predicted square wave to compare against ', ...
    'a physically recorded photodiode trace.'];

% One toggle for the whole experiment. true=white, false=black. Threaded
% explicitly through subfunctions below since they are plain (non-nested)
% local functions and do not share this workspace automatically.
photodiodeToggle = true;

for k = 1:numel(trials)
    tr = trials(k);
    c = configs{k};
    cal = calibration(c.Dark_Background+1);
    bg = cal.backgroundPix;
    timing = double(tr.Timing(:)');
    nFrames = round(timing(2)/ifi);
    duration = nFrames*ifi;
    blank = strcmp(tr.Stimulus_Type,'Blank');
    s = states{k};
    entry = struct();
    entry.trialNumber = k;
    entry.headingDeg = c.Heading;
    entry.isBlank = blank;
    entry.config = c;
    entry.requestedTimingSeconds = timing;
    entry.quantizedStimulusDurationSeconds = duration;
    entry.initialState = s;
    entry.rngBeforeTrialPresentation = rng;
    entry.delayAnchorVbl = vbl;
    modelTimes = nan(1,nFrames);
    vblTimes = nan(1,nFrames);
    onsetTimes = nan(1,nFrames);
    completionTimes = nan(1,nFrames);
    missed = nan(1,nFrames);
    visibleCounts = zeros(1,nFrames);
    drawnCounts = zeros(1,nFrames);
    resets = cell(1,nFrames);
    photodiodeValues = nan(1,nFrames);
    [vbl,aborted,photodiodeToggle,delayLog] = localBackgroundFrames( ...
        w,bg,vbl,round(timing(1)/ifi),ifi,escapeKey,rect,whitePix,blackPix,photodiodeToggle);
    entry.delayFrameVblTimes = delayLog.vblTimes;
    entry.delayFrameOnsetTimes = delayLog.onsetTimes;
    entry.delayFlipMissedSeconds = delayLog.missedFlags;
    entry.delayPhotodiodeSequence = delayLog.photodiodeValues;
    firstVbl = NaN;
    nShown = 0;
    if ~aborted
        for f = 1:nFrames
            if f==1
                elapsed = 0;
            else
                elapsed = vbl+ifi-firstVbl;
                if elapsed>=duration-0.25*ifi
                    break
                end
            end
            Screen('FillRect',w,bg); % explicit clear: no trails
            if ~blank
                [s,frame] = starfieldFlow360('frame',s,elapsed);
                drawnCounts(f) = localDrawWrapped(w,frame,cal,W,whitePix);
                visibleCounts(f) = frame.nVisible;
                resets{f} = frame.resetEvents;
            end
            localDrawPhotodiode(w,rect,photodiodeToggle,whitePix,blackPix);
            [vbl,onset,completed,miss] = Screen('Flip',w,vbl+0.5*ifi);
            if f==1
                firstVbl = vbl;
            end
            modelTimes(f) = elapsed;
            vblTimes(f) = vbl;
            onsetTimes(f) = onset;
            completionTimes(f) = completed;
            missed(f) = miss;
            photodiodeValues(f) = photodiodeToggle;
            photodiodeToggle = ~photodiodeToggle;
            nShown = f;
            if localEscape(escapeKey)
                aborted = true;
                break
            end
        end
    end
    Screen('FillRect',w,bg);
    localDrawPhotodiode(w,rect,photodiodeToggle,whitePix,blackPix);
    [vbl,offsetOnset,~,offsetMissed] = Screen('Flip',w,vbl+0.5*ifi);
    entry.stimulusOffsetOnsetSeconds = offsetOnset;
    entry.stimulusOffsetMissedSeconds = offsetMissed;
    entry.stimulusOffsetPhotodiodeValue = photodiodeToggle;
    photodiodeToggle = ~photodiodeToggle;
    entry.stimulusOnsetVbl = firstVbl;
    entry.stimulusOffsetVbl = vbl;
    entry.actualStimulusDurationSeconds = vbl-firstVbl;
    entry.modelTimeSeconds = modelTimes(1:nShown);
    entry.frameVblTimes = vblTimes(1:nShown);
    entry.frameOnsetTimes = onsetTimes(1:nShown);
    entry.flipCompletionTimes = completionTimes(1:nShown);
    entry.flipMissedSeconds = missed(1:nShown);
    entry.frameIntervalSeconds = diff(vblTimes(1:nShown));
    entry.visibleCenterCounts = visibleCounts(1:nShown);
    entry.drawnCenterCounts = drawnCounts(1:nShown);
    entry.resetEvents = resets(1:nShown); % rows: [pool ID; q; Y; lap]
    entry.photodiodeSequence = photodiodeValues(1:nShown);
    entry.nRenderedFrames = nShown;
    entry.nPositiveMissedFlags = sum(missed(1:nShown)>0);
    entry.nLongFrameIntervals = sum(diff(vblTimes(1:nShown))>1.5*ifi);
    entry.itiStartVbl = vbl;
    entry.itiEndVbl = NaN;
    entry.actualInterTrialGapSeconds = NaN;
    if ~aborted
        % The next trial's first flip completes the last ITI refresh, so do
        % not insert two extra blank frames between trials. Requested zero
        % ITI still includes the explicit one-refresh blank offset above.
        nWait = round(timing(3)/ifi);
        if k<numel(trials)
            nWait = max(0,nWait-1);
        end
        [vbl,aborted,photodiodeToggle,itiLog] = localBackgroundFrames( ...
            w,bg,vbl,nWait,ifi,escapeKey,rect,whitePix,blackPix,photodiodeToggle);
        entry.itiFrameVblTimes = itiLog.vblTimes;
        entry.itiFrameOnsetTimes = itiLog.onsetTimes;
        entry.itiFlipMissedSeconds = itiLog.missedFlags;
        entry.itiPhotodiodeSequence = itiLog.photodiodeValues;
    else
        entry.itiFrameVblTimes = [];
        entry.itiFrameOnsetTimes = [];
        entry.itiFlipMissedSeconds = [];
        entry.itiPhotodiodeSequence = [];
    end
    entry.itiLastBackgroundVbl = vbl;
    entry.aborted = aborted;
    runLog.trials{k} = entry;
    runLog.aborted = aborted;
    if aborted
        break
    end
end
runLog.nTrialsStarted = k;
runLog.endVbl = vbl;
runLog.rngAfterPresentation = rng;
for j = 1:k
    e = runLog.trials{j};
    if j<k
        nextOnset = runLog.trials{j+1}.stimulusOnsetVbl;
        e.itiEndVbl = nextOnset;
        % Includes any next-trial delay and any timing overrun, explicitly.
        e.actualInterTrialGapSeconds = nextOnset-e.stimulusOffsetVbl;
    else
        e.itiEndVbl = e.itiLastBackgroundVbl;
    end
    runLog.trials{j} = e;
end
% onCleanup restores the rig. No errors or synchronization warnings hidden.
end

function localDrawPhotodiode(w,screenRect,toggle,whitePix,blackPix)
% Draws the flip-check box in the corner LeftBoxStim_small uses, alternating
% full-contrast white/black by the current toggle state. Called once per
% logged flip, immediately before Screen('Flip',...).
if toggle
    LeftBoxStim_small(w,screenRect,whitePix);
else
    LeftBoxStim_small(w,screenRect,blackPix);
end
end

function n = localDrawWrapped(w,f,cal,W,whitePix)
if isempty(f.xPix)
    n = 0;
    return
end
index = 1+round(f.visibleContrast*(numel(cal.whiteLUT)-1));
color = cal.whiteLUT(index);
negative = f.polarity<0;
color(negative) = cal.blackLUT(index(negative));
keep = abs(color-cal.backgroundPix)>1e-12;
n = sum(keep);
if n==0
    return
end
x = f.xPix(keep);
y = f.yPix(keep);
d = f.diameterPx(keep);
color = color(keep);
strength = f.visibleContrast(keep);
% Dim stars first; a fading dot cannot overwrite a brighter overlapping dot
% with a near-background disk. This is compositing, not depth-dependent speed.
[~,order] = sort(strength);
x = x(order); y = y(order); d = d(order); color = color(order);
% Include a 1-pixel margin for the anti-aliased circle edge at the arena seam.
left = find(x-d/2-1<0);
right = find(x+d/2+1>W);
xy = [x, x(left)+W, x(right)-W; y, y(left), y(right)];
sizes = [d, d(left), d(right)];
values = [color, color(left), color(right)];
rgba = [repmat(values,3,1); whitePix*ones(1,numel(values))];
Screen('DrawDots',w,xy,sizes,rgba,[],3);
end

function calibration = localCalibration(blackPix,whitePix)
% Scalar calls retain compatibility with non-vectorized lab helpers.
blackLum = PixToLum(blackPix);
whiteLum = PixToLum(whitePix);
assert(isscalar(blackLum) && isscalar(whiteLum) && ...
    isfinite(blackLum) && isfinite(whiteLum) && whiteLum>blackLum, ...
    'PixToLum must give finite increasing black/white luminances.');
a = linspace(0,1,2049);
calibration = repmat(struct('backgroundLum',[],'backgroundPix',[], ...
    'whiteLUT',[],'blackLUT',[]),1,2);
for dark = 0:1
    if dark
        bgLum = blackLum;
    else
        bgLum = (blackLum+whiteLum)/2;
    end
    cal.backgroundLum = bgLum;
    cal.backgroundPix = GammaCorrect(bgLum);
    cal.whiteLUT = arrayfun(@GammaCorrect,bgLum+a*(whiteLum-bgLum));
    cal.blackLUT = arrayfun(@GammaCorrect,bgLum+a*(blackLum-bgLum));
    values = [cal.backgroundPix,cal.whiteLUT,cal.blackLUT];
    assert(all(isfinite(values)) && all(values>=blackPix-1e-6) && ...
        all(values<=whitePix+1e-6), ...
        'GammaCorrect returned values outside the native pixel range. Check calibration.');
    calibration(dark+1) = cal;
end
end

function [vbl,aborted,toggle,log] = localBackgroundFrames( ...
    w,bg,vbl,n,ifi,escapeKey,screenRect,whitePix,blackPix,toggle)
% Draws n background (blank-screen) frames, toggling and logging the
% photodiode box on every flip so delay/ITI frames are traceable too, not
% just the stimulus-bearing ones.
log.vblTimes = nan(1,n);
log.onsetTimes = nan(1,n);
log.missedFlags = nan(1,n);
log.photodiodeValues = nan(1,n);
nDone = 0;
aborted = localEscape(escapeKey);
for f = 1:n
    if aborted
        break
    end
    Screen('FillRect',w,bg);
    localDrawPhotodiode(w,screenRect,toggle,whitePix,blackPix);
    [vbl,onset,~,miss] = Screen('Flip',w,vbl+0.5*ifi);
    nDone = nDone+1;
    log.vblTimes(nDone) = vbl;
    log.onsetTimes(nDone) = onset;
    log.missedFlags(nDone) = miss;
    log.photodiodeValues(nDone) = toggle;
    toggle = ~toggle;
    aborted = localEscape(escapeKey);
end
log.vblTimes = log.vblTimes(1:nDone);
log.onsetTimes = log.onsetTimes(1:nDone);
log.missedFlags = log.missedFlags(1:nDone);
log.photodiodeValues = log.photodiodeValues(1:nDone);
end

function yes = localEscape(escapeKey)
[down,~,code] = KbCheck;
yes = down && any(code(escapeKey));
end

function localCleanup(oldPriority,oldVerbosity,oldVisualDebug)
Priority(oldPriority);
Screen('CloseAll');
ShowCursor;
Screen('Preference','Verbosity',oldVerbosity);
Screen('Preference','VisualDebuglevel',oldVisualDebug);
end