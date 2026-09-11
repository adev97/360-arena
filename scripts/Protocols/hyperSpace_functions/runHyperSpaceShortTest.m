function [trials,meta] = runHyperSpaceShortTest()
% RUNHYPERSPACESHORTTEST Run 11 s of protocol, then terminal-marker housekeeping.
% Changes are local to this call; the normal 905 s design is not overwritten.
[~,design] = makeHyperSpaceProtocol([],true);
design.InitialBlack_s = 1;
design.Stationary_s = 2;
design.Motion_s = 3;
design.Sequence = [1,1;4,3]; % 0 deg at 45 cm/s, then 180 deg at 180 cm/s.
design.BlockRepeats = 1;
design.RandomizeWithinBlock = false; % Deliberately predictable for this test.
[trials,meta] = HyperSpace_master_360dots('HyperSpace_shortTest',design);
end
