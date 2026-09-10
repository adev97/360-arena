function [state, frame] = starfieldFlow360(action, input, argument)
% STARFIELDFLOW360 Pure geometry; no Psychtoolbox dependency.
%
% p = starfieldFlow360('defaults', monitorInfo)
% c = starfieldFlow360('validate', trial, monitorInfo)
% s = starfieldFlow360('init', trial, monitorInfo)
% [s, f] = starfieldFlow360('frame', s, elapsedSeconds)
%
% Full 3-D TRANSLATIONAL flow: stationary world, observer moving horizontally.
% Coordinates: +Z = azimuth 0, +X = azimuth 90, +Y = up.
% Heading h: dr/dt = -v * [sin(h); 0; cos(h)] between hidden wraps.
%
% Visible depth is a viewing window, NOT a physical reflecting boundary.
% World_Geometry 1: vertical cylindrical annulus, Depth_Min <= hypot(X,Z)
%                  <= Depth_Max. 2: spherical radial shell.
% A larger invisible rectangular reservoir surrounds the visible window.
% Stars cross the reservoir from front to back; their longitudinal position
% wraps with overshoot preserved. Lateral coordinate and height are renewed
% ONLY at a wrap, where both old/new positions have zero visible contrast.
% All stars are initially uniform by reservoir volume: no warm-up needed.
%
% Num_Dots is the expected number of dot CENTERS in the displayed depth/FOV
% window BEFORE attenuation, not an exactly constant visible count. Depth
% and vertical-edge fades attenuate contrast, not speed. No angular masks,
% point steering, constant-angular-speed normalization, or tails are used.
% Sizes stay fixed in pixels: this is a motion-only star-field stimulus,
% without perspective size scaling or physical inverse-square brightness.

frame = [];
switch lower(action)
    case 'defaults'
        m = input;
        state = struct( ...
            'Num_Dots', 600, ...
            'Depth_Min', 2*m.radius, ...
            'Depth_Max', 3*m.radius, ...
            'Dot_Size_Min', 2, ...
            'Dot_Size_Max', 4, ...
            'Travel_Speed', 90, ...
            'Heading', 0, ...
            'World_Geometry', 1, ...
            'Boundary_Fade', 0.25*m.radius, ...
            'Vertical_Edge_Fade', 1.5, ...
            'Dark_Background', 1);
    case 'validate'
        state = localConfig(input, argument);
    case 'init'
        c = localConfig(input, argument);
        if c.World_Geometry == 1
            boxY = c.Depth_Max * tand(c.halfHeightDeg);
            visibleVolume = (4*pi/3)*tand(c.halfHeightDeg) * ...
                (c.Depth_Max^3-c.Depth_Min^3);
        else
            boxY = c.Depth_Max * sind(c.halfHeightDeg);
            visibleVolume = (4*pi/3)*sind(c.halfHeightDeg) * ...
                (c.Depth_Max^3-c.Depth_Min^3);
        end
        % Margin ensures a wrap is strictly outside the visible shell.
        boxX = c.Depth_Max;
        boxZ = c.Depth_Max + (c.Depth_Max-c.Depth_Min);
        boxVolume = 8*boxX*boxY*boxZ;
        pVisible = visibleVolume/boxVolume;
        n = max(1, round(c.Num_Dots/pVisible));
        state = struct();
        state.config = c;
        state.nPool = n;
        state.boxHalfSizeCm = [boxX, boxY, boxZ];
        state.visibleVolumeCm3 = visibleVolume;
        state.visibleProbability = pVisible;
        state.expectedGeometricCount = n*pVisible;
        state.rngBeforeInit = rng;
        state.lateralCm = boxX*(2*rand(1,n)-1);
        state.heightCm = boxY*(2*rand(1,n)-1);
        state.phase0Cm = 2*boxZ*rand(1,n);
        state.diameterPx = c.Dot_Size_Min + ...
            (c.Dot_Size_Max-c.Dot_Size_Min)*rand(1,n);
        state.polarity = ones(1,n);
        if ~c.Dark_Background
            state.polarity(rand(1,n)<0.5) = -1;
        end
        state.lastLap = zeros(1,n);
        state.lastTimeSeconds = 0;
        state.rngAfterInit = rng;
    case 'frame'
        state = input;
        t = argument;
        assert(isnumeric(t) && isscalar(t) && isfinite(t) && ...
            t >= state.lastTimeSeconds, ...
            'Frame time must be finite, nonnegative, and nondecreasing.');
        c = state.config;
        L = 2*state.boxHalfSizeCm(3);
        distance = state.phase0Cm + c.Travel_Speed*t;
        lap = floor(distance/L);
        deltaLap = lap-state.lastLap;
        idx = find(deltaLap>0);
        resetEvents = zeros(4,0);
        if ~isempty(idx)
            % Intermediate invisible cycles during a skipped time interval
            % do not need drawing. Sample the final renewed transverse state.
            n = numel(idx);
            state.lateralCm(idx) = state.boxHalfSizeCm(1)*(2*rand(1,n)-1);
            state.heightCm(idx) = state.boxHalfSizeCm(2)*(2*rand(1,n)-1);
            resetEvents = [idx; state.lateralCm(idx); state.heightCm(idx); lap(idx)];
        end
        state.lastLap = lap;
        state.lastTimeSeconds = t;
        q = state.lateralCm;
        Y = state.heightCm;
        zForward = state.boxHalfSizeCm(3) - mod(distance,L);
        h = c.Heading;
        X = q*cosd(h) + zForward*sind(h);
        Z = -q*sind(h) + zForward*cosd(h);
        horizontalRadius = hypot(q,zForward);
        az = mod(atan2d(q,zForward)+h,360);
        el = atan2d(Y,horizontalRadius);
        if c.World_Geometry == 1
            depth = horizontalRadius;
        else
            depth = hypot(horizontalRadius,Y);
        end
        contrast = localSmoothstep((depth-c.Depth_Min)/c.Boundary_Fade) .* ...
            localSmoothstep((c.Depth_Max-depth)/c.Boundary_Fade) .* ...
            localSmoothstep((c.halfHeightDeg-abs(el))/c.Vertical_Edge_Fade);
        visible = contrast>0;
        frame = struct();
        frame.timeSeconds = t;
        frame.xyzCm = [X; Y; Z];
        frame.forwardCoordinateCm = zForward;
        frame.azimuthDeg = az;
        frame.elevationDeg = el;
        frame.depthMetricCm = depth;
        frame.contrast = contrast;
        frame.visibleMask = visible;
        frame.nVisible = sum(visible);
        frame.visibleIds = find(visible);
        frame.xPix = c.widthPx * az(visible)/360;
        frame.yPix = c.heightPx * (0.5-el(visible)/c.heightDeg);
        frame.diameterPx = state.diameterPx(visible);
        frame.polarity = state.polarity(visible);
        frame.visibleContrast = contrast(visible);
        frame.resetEvents = resetEvents;
        frame.nCyclesCrossed = sum(deltaLap);
    otherwise
        error('Unknown starfieldFlow360 action: %s', action);
end
end

function c = localConfig(p,m)
fields = {'Num_Dots','Depth_Min','Depth_Max','Dot_Size_Min','Dot_Size_Max', ...
    'Travel_Speed','Heading','World_Geometry','Boundary_Fade', ...
    'Vertical_Edge_Fade','Dark_Background'};
c = struct();
for k = 1:numel(fields)
    name = fields{k};
    assert(isfield(p,name), 'Missing trial field: %s. Use the NEW star-field master.',name);
    value = p.(name);
    assert(isnumeric(value) && isscalar(value) && isfinite(value), ...
        '%s must be a finite numeric scalar.',name);
    c.(name) = double(value);
end
assert(c.Num_Dots>=1 && c.Num_Dots==floor(c.Num_Dots), ...
    'Num_Dots must be a positive integer (target mean visible center count).');
assert(c.Depth_Min>0 && c.Depth_Max>c.Depth_Min, ...
    'Require 0 < Depth_Min < Depth_Max, in cm.');
assert(c.Dot_Size_Min>0 && c.Dot_Size_Max>=c.Dot_Size_Min, ...
    'Require 0 < Dot_Size_Min <= Dot_Size_Max, in pixels of diameter.');
assert(c.Travel_Speed>=0, 'Travel_Speed must be nonnegative, in cm/s.');
assert(any(c.World_Geometry==[1 2]), 'World_Geometry must be 1 (cylinder) or 2 (sphere).');
assert(any(c.Dark_Background==[0 1]), 'Dark_Background must be 0 or 1.');
assert(c.Boundary_Fade>0 && c.Boundary_Fade <= (c.Depth_Max-c.Depth_Min)/2, ...
    'Boundary_Fade must be positive and at most half the depth-window thickness.');
assert(isfinite(m.screenSizeDegX) && m.screenSizeDegX==360, ...
    'This renderer requires a full 360-degree horizontal display.');
assert(isfinite(m.screenSizeDegY) && m.screenSizeDegY>0 && m.screenSizeDegY<180, ...
    'Vertical FOV must be strictly between 0 and 180 degrees.');
assert(m.screenSizePixX>0 && m.screenSizePixY>0 && ...
    m.screenSizePixX==floor(m.screenSizePixX) && ...
    m.screenSizePixY==floor(m.screenSizePixY), 'Pixel dimensions must be positive integers.');
c.widthPx = m.screenSizePixX;
c.heightPx = m.screenSizePixY;
c.heightDeg = m.screenSizeDegY;
c.halfHeightDeg = m.screenSizeDegY/2;
assert(c.Vertical_Edge_Fade>0 && c.Vertical_Edge_Fade<c.halfHeightDeg, ...
    'Vertical_Edge_Fade must be positive and smaller than half the vertical FOV.');
c.Heading = mod(c.Heading,360);
end

function y = localSmoothstep(x)
x = min(1,max(0,x));
y = x.^2 .* (3-2*x);
end
