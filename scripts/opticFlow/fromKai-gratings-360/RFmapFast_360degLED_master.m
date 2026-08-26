function RFmapFast_360degLED_master(savename)

table = {'Square Size (deg)', 10, 1, 10;...
    'Square PositionX (deg)', -145, 10, 145;...
    'Square PositionY (deg)', -40, 10, 40;...
    'Square Luminance (binary)', 0, 1, 1;...
    'Timing (delay,duration,wait)', 0, 0.095, 0;...
    'Blank', 0, [], [];
    'Randomize', 1, [], [];...
    'Interleave', 0, [], [];...
    'Repeats', 49, [], [];... % if n after 'Repeats', then n+1 rounds in total 
    
    'Initialization Screen (s)', 5, [],[]};
stimType = 'Receptive Field Mapping';

trials = trialStruct_RFmapFast(stimType, table);
ReceptiveFieldMapping_Fast_360degLED(trials);

savename = 'Mouse09_RFmap_Fast_100ms_EB'; 
trialStructSave(trials,savename, 'Trial01');


%% Grating
table = {'Spatial Frequency (cpd)', 0.1, .1, 0.1;...
    'Temporal Frequency (cps)', 3, 1, 3;...
    'Contrast (start,end,numsteps)', 0.75, 0.1, 0.75;...
    'Orientation', 0, 30, 330;...
    'Timing (delay,duration,wait) (s)', 1, 2, 1;...
    'Blank', 0, [], [];
    'Randomize', 1, [], [];...
    'Interleave', 0, [], [];...
    'Repeats', 14, [], [];...
    'Initialization Screen (s)', 5, [],[]};
stimType = 'Full-field Grating';
trials = trialStruct_yuta(stimType, table);

FullFieldGrating_Yuta(trials)
% trialStructSave(trials,savename, 'Gratings');   
% 
% 
% 
% %%;
% trial_num=500;
% trials = [];
% for i=1:trial_num
%     trials(i).Stimulus_Type = 'Full Field Flash';
%     trials(i).Timing = [0.2 0.1 0.1];
%     trials(i).Delay_Shade = 0;
%     trials(i).Duration_Shade = 255;
%     trials(i).Wait_Shade = 0;
% end
% 
% FullFieldFlash(trials)
% 
% trialStructSave(trials,savename, 'Flash');   
% % $$rdr$$
% % 

end
