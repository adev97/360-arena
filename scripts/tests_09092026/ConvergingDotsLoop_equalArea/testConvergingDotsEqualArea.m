function report = testConvergingDotsEqualArea()
% TESTCONVERGINGDOTSEQUALAREA No Psychtoolbox or LED hardware required.
% Tests the SAME numerical helper used by the display.
% Does not test Psychtoolbox, gamma calibration, or your trial/save helpers.

oldRng = rng;
cleanupObj = onCleanup(@() rng(oldRng)); %#ok<NASGU>
rng(20260909, 'twister');
H = 45;
rMin = 61;
rMax = 91.5;
rTarget = (rMin+rMax)/2;

% Endpoint identities and common physical target.
[az, el, xyz] = convergingDotsEqualAreaPosition( ...
    [0 1], [0.31 2.71], H, [rMin rMax], rTarget);
assert(abs(az(1)-180) < 1e-10 && abs(az(2)) < 1e-10);
assert(all(abs(el) < 1e-10));
assert(norm(xyz(:, 2)-[0; 0; rTarget]) < 1e-10);

% Independent initial samples: equal-sized SCREEN bins, not angular rings.
n = 1000000;
phase = rand(1, n);
beta = 2*pi*rand(1, n);
[az, el] = convergingDotsEqualAreaPosition(phase, beta, H, [], []);
assert(all(isfinite(az)) && all(isfinite(el)));
assert(all(az >= 0 & az < 360) && all(abs(el) <= H));
counts = histcounts2(az, el, 0:10:360, -45:10:45);
expected = n/numel(counts);
relativeRMS = std(counts(:), 1)/expected;
maxRelativeDeviation = max(abs(counts(:)-expected))/expected;
assert(maxRelativeDeviation < 0.15, 'Large screen-bin density deviation.');
front = sum(az < 30 | az >= 330);
back = sum(az >= 150 & az < 210);
assert(abs(front/back-1) < 0.025, 'Large front/back density imbalance.');

% The invariant population remains uniform after phase translation/wrapping.
[az2, el2] = convergingDotsEqualAreaPosition(mod(phase+0.371, 1), beta, H, [], []);
counts2 = histcounts2(az2, el2, 0:10:360, -45:10:45);
assert(max(abs(counts2(:)-expected))/expected < 0.15);

% The optional 3-D embedding stays in the stated RADIAL shell.
p = rand(1, 20000);
b = 2*pi*rand(size(p));
spawnR = (rMin^3+(rMax^3-rMin^3)*rand(size(p))).^(1/3);
[~, ~, xyz] = convergingDotsEqualAreaPosition(p, b, H, spawnR, rTarget);
r = sqrt(sum(xyz.^2, 1));
assert(all(r >= rMin-1e-10 & r <= rMax+1e-10));
expectedR = (1-p).*spawnR + p*rTarget;
assert(max(abs(r-expectedR)) < 1e-10);

% Numerical Jacobian (azimuth in radians; elevation in degrees).
p = 0.02+0.96*rand(1, 5000);
b = 2*pi*rand(size(p));
d = 1e-6;
[ap, ep] = convergingDotsEqualAreaPosition(p+d, b, H, [], []);
[am, em] = convergingDotsEqualAreaPosition(p-d, b, H, [], []);
[bp, fp] = convergingDotsEqualAreaPosition(p, b+d, H, [], []);
[bm, fm] = convergingDotsEqualAreaPosition(p, b-d, H, [], []);
dap = deg2rad(mod(ap-am+180, 360)-180)/(2*d);
dab = deg2rad(mod(bp-bm+180, 360)-180)/(2*d);
dep = (ep-em)/(2*d);
deb = (fp-fm)/(2*d);
jacobian = abs(dap.*deb-dab.*dep);
jacobianError = max(abs(jacobian-2*H));
assert(jacobianError < 1e-2, 'Unexpected equal-area Jacobian.');

% True viewing-angle distance from the target decreases along each path.
p = repmat(linspace(1e-7, 1-1e-7, 1001)', 1, 200);
b = repmat(2*pi*rand(1, 200), size(p, 1), 1);
[az, el] = convergingDotsEqualAreaPosition(p, b, H, [], []);
distance = acosd(min(1, max(-1, cosd(el).*cosd(az))));
steps = diff(distance, 1, 1);
assert(all(steps(:) <= 1e-8), 'A trajectory moved away from the target.');

report.samples = n;
report.screenBins = size(counts);
report.expectedCountPerBin = expected;
report.relativeRMS = relativeRMS;
report.maxRelativeDeviation = maxRelativeDeviation;
report.frontCount = front;
report.backCount = back;
report.frontBackRatio = front/back;
report.maxJacobianError = jacobianError;
report.geometryTestsPassed = true;
report.hardwareTested = false;
disp(report);
fprintf('Geometry tests passed. Psychtoolbox/arena integration has NOT been tested here.\n');
end
