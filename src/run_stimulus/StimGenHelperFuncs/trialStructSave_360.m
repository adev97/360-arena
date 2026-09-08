%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%copyright (c) 2012  Matthew Caudill
%
%this program is free software: you can redistribute it and/or modify
%it under the terms of the gnu general public license as published by
%the free software foundation, either version 3 of the license, or
%at your option) any later version.

%this program is distributed in the hope that it will be useful,
%but without any warranty; without even the implied warranty of
%merchantability or fitness for a particular purpose.  see the
%gnu general public license for more details.

%you should have received a copy of the gnu general public license
%along with this program.  if not, see <http://www.gnu.org/licenses/>.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function trialStructSave_360(trials, meta, savename, tag, iftest)

% INPUTS:   Trials, a trial structure 
%           User, user initials provided by the StimGen gui
%           tag, a tag that should match the tag of given by DAQ controller
%
%           Note: user must supply a tag number. The visual stimulation PC
%           has no access to this number. There is a builtin check in this
%           function to ensure the user does not overwrite pre-existing
%           trialstruct files

%%%%%%%%%%%%%%%%%%%%%%%%%%% DEFAULTS FOR TESTING %%%%%%%%%%%%%%%%%%%%%%%%%%%
%trials = [ 1 2 3];
%meta = struct();
%savename = 'OpticFlow';
%tag = 'test_1';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Load dirInformation file containing the DAQPC raw data file address
dirInformation_AD;
% Get the current date and time, formatted YYYYMMDD_HHmmss (zero-padded, no separators)
nowTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
date = char(nowTime);
% Get the user specified save locations from dirInformation
saveDir = dirInfo.DaqPCDataLoc;
% This location specified in RigSpecific dirInfo is the backup save
% location on the local (stimulus) PC
% backupSaveDir=dirInfo.stimuliBackup;
% Get the structure of the save to directory where we intend to save to
s=dir(saveDir);
% Get the names from these structures
names={s(:).name};
%create our target filename -- ORDER: datetime_savename_tag
if iftest == 1
    test = '_test';
    target= [date, '_', savename,'_', tag,test,'.mat'];
elseif iftest == 0
    target= [date, '_', savename,'_', tag,'.mat'];
end
% determine if filename already exist and ask before overwrite
if any(strcmp(target,names))
    answer = questdlg('The file already exist; OVERWRITE?',...
        'Do you want to overwrite','Yes','No','No');
switch answer
case 'Yes'
         save(fullfile(saveDir,target),'trials','meta')
case 'No'
           ME = MException('SaveFile:NO_OVERWRITE', ...
            'USER: PLEASE SELECT A NEW TAG');
          throw(ME);
end
% If the file is not present in the directory then proceed with save
else
    save(fullfile(saveDir,target),'trials','meta');
%save(fullfile(backupSaveDir,target),'trials');
end