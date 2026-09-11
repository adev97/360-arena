function [out, info] = HyperSpaceWorld(action, varargin)
% HYPERSPACEWORLD Persistent XYZ world, independent of Psychtoolbox.
% p = HyperSpaceWorld('defaults', monitorInfo)
% c = HyperSpaceWorld('validate', p, monitorInfo)
% s = HyperSpaceWorld('init', p, monitorInfo)
% [s, events] = HyperSpaceWorld('advance', s, velocityXYZ_cm_s, dt_s)
% frame = HyperSpaceWorld('project', s)
%
% XYZ axes are fixed: +Z=0 deg, +X=90 deg, +Y=up. Never rotate positions
% when the heading changes. Velocity of stars = -speed*[sin(h);0;cos(h)].
% The displayed 2R-3R window and fade laws match the supplied star-field code.
% A larger fixed box supports ANY horizontal travel direction. At an exit,
% respawn on an upstream face, selected in proportion to incoming volume flux.
% Both boundary positions are outside the visible window; residual time is
% integrated after respawn, including multiple exits in one update.
% Zero displacement does not resample anything. There is no random lifetime.
% The engine uses MATLAB's current RNG. The master seeds and restores it.
% events rows: [poolID; secondsFromStepStart; entryX; entryY; entryZ; generation].

info = [];
switch lower(action)
    case 'defaults'
        m = varargin{1};
        out = struct('Num_Dots',600,'Depth_Min',2*m.radius,'Depth_Max',3*m.radius, ...
            'Dot_Size_Min',2,'Dot_Size_Max',4,'World_Geometry',1, ...
            'Boundary_Fade',0.25*m.radius,'Vertical_Edge_Fade',1.5,'Dark_Background',1);
    case 'validate'
        out = localConfig(varargin{1},varargin{2});
    case 'init'
        c = localConfig(varargin{1},varargin{2});
        if c.World_Geometry==1
            by = c.Depth_Max*tand(c.halfHeightDeg);
            volume = (4*pi/3)*tand(c.halfHeightDeg)*(c.Depth_Max^3-c.Depth_Min^3);
        else
            by = c.Depth_Max*sind(c.halfHeightDeg);
            volume = (4*pi/3)*sind(c.halfHeightDeg)*(c.Depth_Max^3-c.Depth_Min^3);
        end
        b = c.Depth_Max+(c.Depth_Max-c.Depth_Min);
        halfBox = [b;by;b];
        probability = volume/(8*prod(halfBox));
        n = max(1,round(c.Num_Dots/probability));
        out = struct();
        out.config = c;
        out.halfBoxCm = halfBox;
        out.nPool = n;
        out.visibleProbability = probability;
        out.expectedGeometricCount = n*probability;
        out.xyzCm = bsxfun(@times,halfBox,2*rand(3,n)-1);
        out.diameterPx = c.Dot_Size_Min+(c.Dot_Size_Max-c.Dot_Size_Min)*rand(1,n);
        out.polarity = ones(1,n);
        if ~c.Dark_Background, out.polarity(rand(1,n)<0.5) = -1; end
        out.generation = zeros(1,n);
        out.totalAdvanceSeconds = 0;
    case 'advance'
        out = varargin{1};
        v = double(varargin{2}(:));
        dt = varargin{3};
        assert(numel(v)==3 && all(isfinite(v)) && isreal(v) && v(2)==0, ...
            'Velocity must be a finite horizontal XYZ vector, in cm/s.');
        assert(isnumeric(dt) && isscalar(dt) && isfinite(dt) && dt>=0, ...
            'dt must be finite and nonnegative.');
        info = zeros(6,0);
        if dt==0 || ~any(v), return; end
        out.totalAdvanceSeconds = out.totalAdvanceSeconds+dt;
        b = out.halfBoxCm;
        % Incoming flux is speed normal to a face times that face's area.
        fluxX = abs(v(1))*b(3);
        fluxZ = abs(v(3))*b(1);
        pXFace = fluxX/(fluxX+fluxZ);
        ids = 1:out.nPool;
        remaining = dt*ones(1,out.nPool);
        while ~isempty(ids)
            xyz = out.xyzCm(:,ids);
            tx = inf(1,numel(ids)); tz = tx;
            if v(1)~=0, tx = (sign(v(1))*b(1)-xyz(1,:))/v(1); end
            if v(3)~=0, tz = (sign(v(3))*b(3)-xyz(3,:))/v(3); end
            exitTime = min(tx,tz);
            assert(all(exitTime>=-1e-9), 'A star is unexpectedly outside the reservoir.');
            exitTime = max(0,exitTime); % Roundoff only, at an exact boundary.
            used = min(remaining,exitTime);
            out.xyzCm(:,ids) = xyz+v*used;
            crossing = exitTime<=remaining;
            remaining = remaining(crossing)-used(crossing);
            ids = ids(crossing);
            if isempty(ids), break; end
            n = numel(ids);
            entry = bsxfun(@times,b,2*rand(3,n)-1);
            onX = rand(1,n)<pXFace;
            entry(1,onX) = -sign(v(1))*b(1);
            entry(3,~onX) = -sign(v(3))*b(3);
            out.xyzCm(:,ids) = entry;
            out.generation(ids) = out.generation(ids)+1;
            info = [info,[ids;dt-remaining;entry;out.generation(ids)]]; %#ok<AGROW>
            % Exact-boundary resets are recorded even with zero residual time.
            keep = remaining>0;
            ids = ids(keep); remaining = remaining(keep);
        end
    case 'project'
        s = varargin{1}; c = s.config;
        X = s.xyzCm(1,:); Y = s.xyzCm(2,:); Z = s.xyzCm(3,:);
        radius = hypot(X,Z);
        az = mod(atan2d(X,Z),360);
        el = atan2d(Y,radius);
        depth = radius;
        if c.World_Geometry==2, depth = hypot(radius,Y); end
        contrast = smoothstep((depth-c.Depth_Min)/c.Boundary_Fade).* ...
            smoothstep((c.Depth_Max-depth)/c.Boundary_Fade).* ...
            smoothstep((c.halfHeightDeg-abs(el))/c.Vertical_Edge_Fade);
        visible = contrast>0;
        out = struct('xPix',c.widthPx*az(visible)/360, ...
            'yPix',c.heightPx*(0.5-el(visible)/c.heightDeg), ...
            'diameterPx',s.diameterPx(visible),'polarity',s.polarity(visible), ...
            'visibleContrast',contrast(visible),'visibleIds',find(visible), ...
            'nVisible',sum(visible),'azimuthDeg',az,'elevationDeg',el, ...
            'depthMetricCm',depth,'contrast',contrast);
    otherwise
        error('HyperSpace:WorldAction','Unknown world action: %s',action);
end
end

function c = localConfig(p,m)
fields = {'Num_Dots','Depth_Min','Depth_Max','Dot_Size_Min','Dot_Size_Max', ...
    'World_Geometry','Boundary_Fade','Vertical_Edge_Fade','Dark_Background'};
c = struct();
for j = 1:numel(fields)
    name = fields{j};
    assert(isfield(p,name),'Missing world parameter: %s',name);
    validateattributes(p.(name),{'numeric'},{'scalar','real','finite'},mfilename,name);
    c.(name) = double(p.(name));
end
assert(c.Num_Dots>=1 && c.Num_Dots==fix(c.Num_Dots),'Num_Dots must be a positive integer.');
assert(c.Depth_Min>0 && c.Depth_Max>c.Depth_Min,'Require 0 < Depth_Min < Depth_Max.');
assert(c.Dot_Size_Min>0 && c.Dot_Size_Max>=c.Dot_Size_Min,'Invalid dot diameters.');
assert(any(c.World_Geometry==[1,2]),'World_Geometry must be 1 or 2.');
assert(any(c.Dark_Background==[0,1]),'Dark_Background must be 0 or 1.');
assert(c.Boundary_Fade>0 && c.Boundary_Fade<=(c.Depth_Max-c.Depth_Min)/2, ...
    'Boundary_Fade must be positive and <= half the depth-window thickness.');
assert(m.screenSizeDegX==360 && m.screenSizeDegY>0 && m.screenSizeDegY<180, ...
    'Require 360 horizontal degrees and 0 < vertical FOV < 180.');
validateattributes(m.screenSizePixX,{'numeric'},{'scalar','finite','integer','positive'});
validateattributes(m.screenSizePixY,{'numeric'},{'scalar','finite','integer','positive'});
c.widthPx = m.screenSizePixX; c.heightPx = m.screenSizePixY;
c.heightDeg = m.screenSizeDegY; c.halfHeightDeg = m.screenSizeDegY/2;
assert(c.Vertical_Edge_Fade>0 && c.Vertical_Edge_Fade<c.halfHeightDeg, ...
    'Vertical_Edge_Fade must be positive and less than half the FOV.');
end

function y = smoothstep(x)
x = min(1,max(0,x));
y = x.^2.*(3-2*x);
end
