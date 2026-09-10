function monitorInfo = getMonitorInformation()
% Arena configuration supplied in the original request; values unchanged.
monitorInfo.screenNumber = 2;
monitorInfo.screenSizeDegX = 360;
monitorInfo.screenSizeDegY = 90;
monitorInfo.screenSizePixX = 960;
monitorInfo.screenSizePixY = 240;
monitorInfo.degPerPix = monitorInfo.screenSizeDegX / monitorInfo.screenSizePixX;
monitorInfo.radius = 61/2; % cm
monitorInfo.powerLawScaleFactor = .0001801;
monitorInfo.gamma = 2.386;
end
