function [run] = LoadAcceleroData(run, ID, data_dir, varargin)
%     %%%%%%% LoadAcceleroData.m %%%%%%
%   Use as [run] = LoadAcceleroData(run, ID, data_dir, varargin)
%
% Loads all poly5 files for 1 participant and extracts the accelerometer channels in fieldtrip format (run.data_accelero).
% Trigger timepoints are extracted from the digi channel and time axis of the data is redefined such that t=0 is the
% start of the run. accelerometer data is added to the run structure as
% data_accelero.
%
%%% INPUT %%%
%       run    = run structure which already holds the data_ECG and
%       the events
%       ID         =  participant ID (e.g. '110001'); 
%       data_dir   = directory where the poly5 files are saved
% Additional options can be specified in key-value pairs and can be:
%       'quality_check'    = 1 or 0. 1 for quality check during loading of data; 0 for no
%       quality check (default =0)
%       'vis'        =  1 or 0 for visualizing the accelerometer data
%       together with the heart rate data (default = 0)
%
%%% OUTPUT %%%
%       run (structure) = run structure where data_accelero has been added.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Get the options
qual_check = ft_getopt(varargin, 'quality_check', 0);
vis= ft_getopt(varargin, 'vis', 0);

%% Load in data
poly5=dir(fullfile(data_dir, ID, '110110 201*', 'Porti*', 'Porti*.Poly5'));
if isempty(poly5)
  warning('No poly5 files are found. Please make sure you are connected to the file server (data_dir)')
end
% exceptions
switch ID
  case '110001'
  % run 5 and 6 are empty for ECG data (see HC_runinfo)
  warning('run 5 and 6 are empty for ECG data, not loading the motion data for these runs')
  poly5=poly5([1:4]);
  case '110002'
    warning('run 4 was too short, skipping this run')
    poly5=poly5([1:3 5]);
  case '110004'
  warning('poly5-file number 6 was almost empty. Not using this file as a run')
  poly5=poly5([1:5 7]);
end
for i=1:length(poly5)
    fprintf('........processing run %d........ \n', i)
    filename=fullfile(poly5(i).folder, poly5(i).name);
    % read into fieldtrip
    cfg=[];
    cfg.channel=[25 26 10 31 32 16 33]; % only select channels of right ankle accelerometer (X,Y,Z), left ankle accelerometer (X,Y,Z) and digi channel respectively
    cfg.dataset=filename; 
    cfg.feedback='no';
    data=ft_preprocessing(cfg);
    % rename labels
    data.label(1:6)={'RF_X', 'RF_Y', 'RF_Z', 'LF_X', 'LF_Y', 'LF_Z'};
    
    % define triggers
    triggers=ft_read_event(filename, 'detectflank', 'up');
    if qual_check & length(triggers)>1
      warning('More than one event detected. Using the last event to redefine the time axis. Please check in the figure if this is correct.');
      figure; plot(data.time{1}, data.trial{1}(end,:));
      hold on; plot(triggers(end).sample/data.fsample, 6, 'o');
      title('Please check whether the correct trigger event is detected. Press enter to continue.')
      pause;
      triggers=triggers(end);
    elseif length(triggers)>1
      warning('More than one event detected. Using the last event to redefine the time axis. Please check in the figure if this is correct.');
      triggers=triggers(end);
    end
    if vis
      figure; plot(data.time{1}, data.trial{1}(end,:));
      hold on; plot(triggers.sample/data.fsample, 6, 'o');
    end
    
    % redefine time axis of data to the start of run (trigger --> t=0)
    cfg=[];
    cfg.offset=-triggers.sample;
    data_ses=ft_redefinetrial(cfg, data);
    
    % remove the digi channel
    cfg=[];
    cfg.channel={'RF_X', 'RF_Y', 'RF_Z', 'LF_X', 'LF_Y', 'LF_Z'};
    data_ses=ft_selectdata(cfg, data_ses);

    % run 4 of ID110001 is empty from 260 sec. on
    if strcmp(ID, '110001') & i==4
      cfg=[];
      cfg.latency=[data_ses.time{1}(1) 260];
      data_ses=ft_selectdata(cfg, data_ses);
    end
    
    % convert to acceleration values in g
    zero_output = 1500; % in mV, see datasheet accelerometer
    sensitivity = 300;
    aux_channels=find(contains(data_ses.label, {'X', 'Y'}));
    bip_channels=find(contains(data_ses.label, {'Z'}));
    data_ses.trial{1}(aux_channels,:)= (data_ses.trial{1}(aux_channels,:)/1000-zero_output)/sensitivity; % formula see email TMSi december 2020
    data_ses.trial{1}(bip_channels,:)= ((data_ses.trial{1}(bip_channels,:)/1000-zero_output)/sensitivity)*20;
    
    % combine all 3 axes to one
    RF_abs=(data_ses.trial{1}(1,:).^2+data_ses.trial{1}(2,:).^2+data_ses.trial{1}(3,:).^2).^(1/2); % see Ying
    LF_abs=(data_ses.trial{1}(4,:).^2+data_ses.trial{1}(5,:).^2+data_ses.trial{1}(6,:).^2).^(1/2);
    data_ses.label(7:8)={'RF_abs', 'LF_abs'}; % add to data
    data_ses.trial{1}(7:8,:)=[RF_abs; LF_abs];

    % browse data & check quality 
    if qual_check
      cfg=[];
        cfg.blocksize=60;
        cfg.demean='yes';
        cfg.viewmode='vertical';
        cfg.ylim=[-1 1];
        cfg.event=run(i).events(find(ismember({run(i).events.type}, {'Gait_events', 'FOG_Trigger'}))); % only plot the FOG_Triggers and the Gait_events
        cfg.plotevents='yes';
        cfg.ploteventlabels='colorvalue';
        ft_databrowser(cfg, data_ses); 
    end
    if vis
      % combine with heartrate data
      cfg=[];
      data_combi= ft_appenddata(cfg, run(i).variables, data_ses);
        cfg=[];
        cfg.channel={'heartrate', 'RF_X', 'LF_X'};
        cfg.blocksize=60;
        cfg.demean='yes';
        cfg.viewmode='vertical';
        cfg.mychanscale=[1; 20; 20];
        cfg.mychan={'heartrate', 'RF_X', 'LF_X'};
        cfg.ylim=[-50 50];
        cfg.event=run(i).events(find(ismember({run(i).events.type}, {'Gait_events', 'FOG_Trigger'}))); % only plot the FOG_Triggers and the Gait_events
        cfg.plotevents='yes';
        cfg.ploteventlabels='colorvalue';
        ft_databrowser(cfg, data_combi); 
    end
    
    % add to data structure
    run(i).data_accelero=data_ses;
   
end

