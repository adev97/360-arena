function [azimuthDeg, elevationDeg, XYZ] = convergingDotsEqualAreaPosition( ...
    phase, beta, halfHeightDeg, spawnRadiusCm, targetDepthCm)
% CONVERGINGDOTSEQUALAREAPOSITION Exact continuous-model position map.
%
% Inputs phase and beta are equally sized row vectors.
% phase: fraction of one traversal, in [0,1]; display wraps it into [0,1).
% beta:  path angle in radians, uniform on [0,2*pi), fixed during a traversal.
% halfHeightDeg: half the displayed vertical angular range (45 on this rig).
% spawnRadiusCm: per-dot initial radius for the OPTIONAL 3-D embedding.
% targetDepthCm: common radius of the front target.
%
% phase=0 -> back source (az=180, el=0).
% phase=1 -> front target (az=0, el=0).
%
% Uniform phase and beta produce a uniform auxiliary sphere. Mapping its
% horizontal bearing and vertical Cartesian coordinate to the screen is
% equal-area. In radians/degrees coordinates:
% abs(det(d[azimuth,elevation]/d[phase,beta])) = 2*halfHeightDeg.
% This guarantees uniform expected DOT-CENTER density in the display
% rectangle, NOT uniform physical solid angle or uniform 3-D volume.
%
% With a third output, XYZ is 3-by-N in the original coordinate convention:
% X=r*cos(el)*sin(az), Y=r*sin(el), Z=r*cos(el)*cos(az).
% Radius interpolates from spawnRadiusCm to targetDepthCm, so it stays
% between those radii. Display does not need XYZ; depth then has no effect
% on rendered position or size. These viewer-space paths are not, in
% general, straight lines or great-circle arcs.
%
% Inputs are validated once in the display caller, not on every frame.

z = 2*phase - 1;
q = sqrt(max(0, 1 - z.^2)); % max only protects square-root roundoff
auxX = q .* cos(beta);
auxY = q .* sin(beta);

azimuthDeg = mod(atan2d(auxX, z), 360);
elevationDeg = halfHeightDeg * auxY; % deliberately NOT asind(auxY)

if nargout > 2
    radiusCm = (1-phase).*spawnRadiusCm + phase.*targetDepthCm;
    cosEl = cosd(elevationDeg);
    XYZ = [radiusCm .* cosEl .* sind(azimuthDeg); ...
           radiusCm .* sind(elevationDeg); ...
           radiusCm .* cosEl .* cosd(azimuthDeg)];
end
end
