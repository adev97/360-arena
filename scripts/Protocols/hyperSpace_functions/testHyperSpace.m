function report = testHyperSpace()
% TESTHYPERSPACE Geometry/schedule tests; no Psychtoolbox or acquisition.
% Tests the same world and refresh-clock functions used by the renderer.
% It cannot validate the physical arena, luminance, diode, or display timing.
oldRng = rng;
cleanup = onCleanup(@() rng(oldRng)); %#ok<NASGU>
rng(123,'twister');
m = struct('radius',30.5,'screenSizeDegX',360,'screenSizeDegY',90, ...
    'screenSizePixX',960,'screenSizePixY',240);
[protocol,design] = makeHyperSpaceProtocol([],true);
assert(height(protocol)==37 && design.NumTrials==18 && design.TotalNominalSeconds==905);
assert(design.RandomizeWithinBlock);
moving = protocol.Mode=="move";
assert(size(unique([protocol.Heading_deg(moving),protocol.Speed_cm_s(moving)],'rows'),1)==18);
assert(all(protocol.Mode(2:2:end)=="stationary") && all(protocol.Mode(3:2:end)=="move"));
assert(isequal(protocol.TrialID(2:2:end),protocol.TrialID(3:2:end)));
assert(all(protocol.PhotodiodeValue(2:2:end)==1) && all(protocol.PhotodiodeValue(3:2:end)==0));
assert(all(abs(diff(protocol.PhotodiodeValue))==1));
[p2,~] = makeHyperSpaceProtocol(design,true);
assert(isequaln(protocol,p2),'Same design/seed did not reproduce the schedule.');
ifi = 1/60;
plan = HyperSpaceFrameClock('compile',protocol,ifi);
assert(plan.maxFrames==54300 && sum(plan.duration)==905);
assert(all(all(plan.velocity(:,~moving)==0)));
assert(max(abs(sqrt(sum(plan.velocity(:,moving).^2,1))-protocol.Speed_cm_s(moving)'))<1e-10);
assert(HyperSpaceFrameClock('next',0,100,100,ifi)==1);
assert(HyperSpaceFrameClock('next',1,100+3*ifi,100,ifi)==4);
assert(HyperSpaceFrameClock('next',5,100+2*ifi,100,ifi)==6);
assert(1-protocol.PhotodiodeValue(end)==1,'Final offset must invert the last patch state.');

maxTranslationError = 0;
totalEvents = 0;
for geometry = [1,2]
    p = HyperSpaceWorld('defaults',m); p.World_Geometry = geometry;
    s = HyperSpaceWorld('init',p,m);
    initial = s;
    [frozen,events] = HyperSpaceWorld('advance',s,[0;0;0],20);
    assert(isequaln(frozen,initial) && isempty(events),'Stationary update changed the world.');
    assert(isequaln(HyperSpaceWorld('project',s),HyperSpaceWorld('project',frozen)));
    for heading = [0,60,120,180,240,300,37]
        for speed = [45,90,180]
            v = -speed*[sind(heading);0;cosd(heading)];
            previous = s;
            [s,events] = HyperSpaceWorld('advance',s,v,ifi);
            untouched = true(1,s.nPool);
            untouched(unique(events(1,:))) = false;
            residual = s.xyzCm(:,untouched)-previous.xyzCm(:,untouched)-v*ifi;
            maxTranslationError = max(maxTranslationError,max(abs(residual(:))));
            assert(max(abs(residual(:)))<1e-9,'Nonreset stars did not share one displacement.');
            assert(isequal(s.diameterPx,initial.diameterPx) && isequal(s.polarity,initial.polarity));
            if ~isempty(events)
                assert(all(hypot(events(3,:),events(5,:))>p.Depth_Max), ...
                    'A reset entry is inside the visible depth window.');
                assert(all(events(2,:)>=0 & events(2,:)<=ifi));
                totalEvents = totalEvents+size(events,2);
            end
            assert(all(all(abs(s.xyzCm)<=s.halfBoxCm+1e-9)),'Reservoir bounds violated.');
            frame = HyperSpaceWorld('project',s);
            ids = frame.visibleIds;
            assert(all(frame.depthMetricCm(ids)>p.Depth_Min & frame.depthMetricCm(ids)<p.Depth_Max));
            assert(all(frame.xPix>=0 & frame.xPix<960 & frame.yPix>0 & frame.yPix<240));
            beforeTurn = s;
            [s,noEvents] = HyperSpaceWorld('advance',s,-v,0);
            assert(isequaln(s,beforeTurn) && isempty(noEvents),'Heading switch rotated the scene.');
        end
    end
    % Force many hidden cycles with a small pool and one long update.
    s.nPool = 6; s.xyzCm = s.xyzCm(:,1:6); s.diameterPx = s.diameterPx(1:6);
    s.polarity = s.polarity(1:6); s.generation = s.generation(1:6);
    [s,events] = HyperSpaceWorld('advance',s,[-180;0;0],10);
    assert(size(events,2)>6 && all(all(abs(s.xyzCm)<=s.halfBoxCm+1e-9)));
    assert(all(hypot(events(3,:),events(5,:))>p.Depth_Max));
end
% Basic projection direction: at heading zero, azimuth increases on right,
% decreases on left. A 180-degree heading reverses this without scene rotation.
p = HyperSpaceWorld('defaults',m); s = HyperSpaceWorld('init',p,m);
s.nPool = 2; s.xyzCm = [70,-70;0,0;30,30];
s.diameterPx = [2,2]; s.polarity = [1,1]; s.generation = [0,0];
f0 = HyperSpaceWorld('project',s);
s1 = HyperSpaceWorld('advance',s,[0;0;-90],ifi);
f1 = HyperSpaceWorld('project',s1);
assert(f1.azimuthDeg(1)>f0.azimuthDeg(1) && f1.azimuthDeg(2)<f0.azimuthDeg(2));
s2 = HyperSpaceWorld('advance',s,[0;0;90],ifi);
f2 = HyperSpaceWorld('project',s2);
assert(f2.azimuthDeg(1)<f0.azimuthDeg(1) && f2.azimuthDeg(2)>f0.azimuthDeg(2));
report = struct('geometryAndSchedulePassed',true,'phases',height(protocol), ...
    'movementTrials',design.NumTrials,'nominalSeconds',design.TotalNominalSeconds, ...
    'maxTranslationError_cm',maxTranslationError,'testedHiddenEntries',totalEvents, ...
    'photodiodeMode','phase-boundary toggle','hardwareTested',false);
disp(report);
fprintf('HyperSpace geometry/schedule tests passed. Arena and OneBox are NOT tested.\n');
end
