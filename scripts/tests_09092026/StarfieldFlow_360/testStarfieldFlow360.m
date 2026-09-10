function report = testStarfieldFlow360()
% TESTSTARFIELDFLOW360 Numerical tests of the actual MATLAB geometry helper.
% Does not open a window and does not require Psychtoolbox or lab save helpers.
% Passing this test does NOT validate arena mapping, calibration, or timing.
oldRng = rng;
restoreRng = onCleanup(@() rng(oldRng)); %#ok<NASGU>
m = getMonitorInformation();
report = struct();
report.model = 'starfieldTranslation_v1';
report.geometry = cell(1,2);
for geometry = 1:2
    rng(11,'twister');
    p = starfieldFlow360('defaults',m);
    p.World_Geometry = geometry;
    p.Num_Dots = 600;
    s0 = starfieldFlow360('init',p,m);
    [s0,f0] = starfieldFlow360('frame',s0,0);
    dt = 0.001;
    [s1,f1] = starfieldFlow360('frame',s0,dt);
    unchanged = s1.lastLap==s0.lastLap;
    velocity = -p.Travel_Speed*[sind(p.Heading);0;cosd(p.Heading)];
    error = bsxfun(@minus,f1.xyzCm(:,unchanged)-f0.xyzCm(:,unchanged),velocity*dt);
    maxError = max(abs(error(:)));
    assert(maxError<1e-10,'A non-wrapped star did not receive the common 3-D displacement.');

    use = unchanged & f0.visibleMask & f1.visibleMask;
    a0 = atan2d(sind(f0.azimuthDeg-p.Heading),cosd(f0.azimuthDeg-p.Heading));
    dAz = atan2d(sind(f1.azimuthDeg-f0.azimuthDeg),cosd(f1.azimuthDeg-f0.azimuthDeg));
    right = use & a0>0 & a0<180;
    left = use & a0<0 & a0>-180;
    assert(any(right) && any(left),'Insufficient test samples on both sides.');
    assert(all(dAz(right)>0) && all(dAz(left)<0), ...
        'Flow must expand at heading and contract at heading+180.');
    depth = f0.depthMetricCm(f0.visibleMask);
    assert(all(depth>p.Depth_Min) && all(depth<p.Depth_Max),'A rendered point is outside its depth window.');
    assert(all(abs(f0.elevationDeg(f0.visibleMask))<m.screenSizeDegY/2), ...
        'A rendered center is outside the vertical FOV.');
    r = f0.xyzCm(:,f0.visibleMask);
    r2 = sum(r.^2,1);
    v = repmat(velocity,1,size(r,2));
    angularSpeed = sqrt(sum(cross(r,v,1).^2,1))./r2;
    assert(all(angularSpeed<=p.Travel_Speed/p.Depth_Min+1e-12), ...
        'Visible angular speed exceeded its near-depth bound.');

    % An explicit boundary crossing: both positions have zero contrast.
    L = 2*s0.boxHalfSizeCm(3);
    s = s0;
    s.phase0Cm(1) = L-1e-4;
    [s,before] = starfieldFlow360('frame',s,0);
    [~,after] = starfieldFlow360('frame',s,2e-4/p.Travel_Speed);
    assert(before.contrast(1)==0 && after.contrast(1)==0 && ...
        any(after.resetEvents(1,:)==1),'A reservoir reset was not hidden.');

    % Retain overshoot even after multiple complete reservoir traversals.
    t = 3.25*L/p.Travel_Speed;
    [~,late] = starfieldFlow360('frame',s0,t);
    expectedZ = s0.boxHalfSizeCm(3)-mod(s0.phase0Cm+p.Travel_Speed*t,L);
    assert(max(abs(late.forwardCoordinateCm-expectedZ))<1e-12,'Long-step wrap lost overshoot.');

    % Heading rotation must rotate azimuth, not change elevation or contrast.
    for heading = [0,-60,-120,180,120,60]
        s = s0;
        s.config.Heading = heading;
        [~,rotated] = starfieldFlow360('frame',s,0);
        eAz = atan2d(sind(rotated.azimuthDeg-f0.azimuthDeg-heading), ...
            cosd(rotated.azimuthDeg-f0.azimuthDeg-heading));
        assert(max(abs(eAz))<1e-10 && ...
            max(abs(rotated.elevationDeg-f0.elevationDeg))<1e-10 && ...
            isequal(rotated.contrast,f0.contrast),'Heading covariance failed.');
    end

    % Reflection in front/back leaves all visibility/contrast weights equal.
    s = s0;
    s.phase0Cm = mod(L-s.phase0Cm,L);
    [~,reflected] = starfieldFlow360('frame',s,0);
    symmetryError = max(abs(reflected.contrast-f0.contrast));
    assert(symmetryError<1e-10,'Front/back visibility weighting is asymmetric.');

    % Independent large initial world: azimuth coverage, not pixel uniformity.
    p.Num_Dots = 100000;
    rng(123,'twister');
    large = starfieldFlow360('init',p,m);
    [~,f] = starfieldFlow360('frame',large,0);
    counts = histcounts(f.azimuthDeg(f.visibleMask),0:10:360);
    assert(all(counts>0),'An angular sector has no coverage.');
    relativeAz = atan2d(sind(f.azimuthDeg-p.Heading),cosd(f.azimuthDeg-p.Heading));
    front = sum(f.visibleMask & abs(relativeAz)<30);
    back = sum(f.visibleMask & abs(relativeAz)>150);
    result = struct();
    result.worldGeometry = geometry;
    result.maxTranslationErrorCm = maxError;
    result.maxFrontBackContrastError = symmetryError;
    result.largeTestPoolSize = large.nPool;
    result.largeTestVisibleCount = f.nVisible;
    result.largeTestExpectedVisibleCount = large.expectedGeometricCount;
    result.azimuthBinCounts = counts;
    result.azimuthRelativeRMS = sqrt(mean((counts/mean(counts)-1).^2));
    result.frontCount = front;
    result.backCount = back;
    result.frontBackRatio = front/back;
    result.maxVisibleAngularSpeedDegps = max(angularSpeed)*180/pi;
    result.directionBoundsWrapAndHeadingPassed = true;
    report.geometry{geometry} = result;
end

p = starfieldFlow360('defaults',m);
p.Travel_Speed = 0;
s = starfieldFlow360('init',p,m);
[s,a] = starfieldFlow360('frame',s,0);
[~,b] = starfieldFlow360('frame',s,1000);
assert(isequal(a.xyzCm,b.xyzCm) && isequal(a.contrast,b.contrast) && ...
    isempty(b.resetEvents),'Zero speed must produce a static field.');
report.zeroSpeedPassed = true;
report.geometryTestsPassed = true;
report.hardwareTested = false;
disp(report);
for k = 1:2
    disp(report.geometry{k});
end
fprintf(['Geometry tests passed. Psychtoolbox/arena mapping, luminance, ', ...
    'and timing have NOT been validated by this test.\n']);
end
