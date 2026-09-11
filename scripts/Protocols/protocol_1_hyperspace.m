% PROTOCOL_1_HYPERSPACE
% Save beside HyperSpace_master_360dots.m.

% Add the arena repository and its subfolders.
addpath(genpath('C:\Users\Senzai Lab\Documents\GitHub\360-arena'), '-begin');

% Prioritize the HyperSpace files beside this script.
addpath(fileparts(mfilename('fullpath')), '-begin');

% Load your existing protocol settings. Edit speed and direction here
[protocol, design] = makeHyperSpaceProtocol();

% Confirm OneBox recording before starting the display.
input('Start OneBox recording, then press Enter to run (Ctrl+C to cancel): ', 's');

% Run the full protocol. Edit dot numnber and size here
[trials, meta] = HyperSpace_master_360dots('hyperspace_protocol_1', design);