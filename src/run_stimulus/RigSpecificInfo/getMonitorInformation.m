function monitorInfo = getMonitorInformation()
%   monitorInfo = getMonitorInformation()

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file contains all the monitor information for the 360 Neuropixel arena;
% all information is stored in a monitor structure

%%%%%%%%%%%%%%%%%%%%%%%% MONITOR INFORMATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

monitorInfo.screenNumber = 2;
monitorInfo.screenSizeDegX = 360;
monitorInfo.screenSizeDegY = 90;
monitorInfo.screenSizePixX = 960;
monitorInfo.screenSizePixY = 240;
monitorInfo.degPerPix = monitorInfo.screenSizeDegX/...
    monitorInfo.screenSizePixX;
monitorInfo.radius = 61/2; % cm

monitorInfo.powerLawScaleFactor = .0001801;
monitorInfo.gamma = 2.386;