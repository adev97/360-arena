function out = HyperSpaceFrameClock(action, varargin)
% HYPERSPACEFRAMECLOCK Refresh-quantized schedule and late-frame catch-up.
% plan = HyperSpaceFrameClock('compile', protocol, ifi)
% slot = HyperSpaceFrameClock('next', previousSlot, previousVBL, firstVBL, ifi)
% Slots start at zero. Motion advances one ifi on its first moving frame.
% Subsequent updates catch up to the elapsed refresh grid, not arbitrary
% sub-frame jitter in the previous VBL timestamp. Never skip a WHOLE phase.
% A missed flip can still elongate a phase; actual timestamps are authoritative.
switch lower(action)
    case 'compile'
        t = varargin{1}; ifi = varargin{2};
        validateattributes(ifi,{'numeric'},{'scalar','finite','positive'});
        assert(istable(t) && height(t)>0,'protocol must be a nonempty table.');
        required = {'PhaseID','BlockID','TrialID','Mode','Condition','Duration_s', ...
            'Heading_deg','Speed_cm_s','PhotodiodeValue'};
        assert(all(ismember(required,t.Properties.VariableNames)),'Invalid protocol columns.');
        assert(isequal(t.PhaseID,(1:height(t))'),'PhaseID must be consecutive from 1.');
        assert(all(isfinite(t.Duration_s) & t.Duration_s>0),'Invalid phase duration.');
        assert(all(ismember(t.Mode,["black","stationary","move"])),'Invalid phase mode.');
        assert(all(ismember(t.PhotodiodeValue,[0,1])) && ...
            all(abs(diff(t.PhotodiodeValue))==1) && t.PhotodiodeValue(1)==0, ...
            'Option 1 requires an initial black patch and a toggle at every phase.');
        out = struct();
        out.ifi = ifi;
        out.nPhases = height(t);
        out.frames = round(t.Duration_s/ifi);
        assert(all(out.frames>=1),'A phase is shorter than one display refresh.');
        out.duration = out.frames*ifi;
        out.velocity = zeros(3,height(t));
        moving = t.Mode=="move";
        assert(all(isfinite(t.Heading_deg(moving))) && ...
            all(isfinite(t.Speed_cm_s(moving)) & t.Speed_cm_s(moving)>0), ...
            'Moving phases need finite headings and positive speeds.');
        assert(all(t.Speed_cm_s(~moving)==0),'Nonmoving phases must have speed zero.');
        out.velocity(1,moving) = -t.Speed_cm_s(moving)'.*sind(t.Heading_deg(moving)');
        out.velocity(3,moving) = -t.Speed_cm_s(moving)'.*cosd(t.Heading_deg(moving)');
        out.isMoving = moving;
        out.isBlack = t.Mode=="black";
        out.marker = t.PhotodiodeValue;
        out.maxFrames = sum(out.frames);
    case 'next'
        previousSlot = varargin{1};
        previousVBL = varargin{2};
        firstVBL = varargin{3};
        ifi = varargin{4};
        assert(isfinite(previousVBL) && isfinite(firstVBL) && ifi>0, ...
            'Invalid timestamp or refresh interval.');
        out = max(previousSlot+1,round((previousVBL-firstVBL)/ifi)+1);
    otherwise
        error('HyperSpace:ClockAction','Unknown clock action: %s',action);
end
end
