function [run] = LoadECGData(ID, data_dir, varargin)
%     %%%%%%% LoadData.m %%%%%%
% Loads all poly5 files for 1 participant and extracts the ECG + Digi channels in fieldtrip format (run.data).
% 6 limb leads (I, II, III, aVL, aVR and aVF) are calculated and added as
% channels to the data_ECG structure. Trigger timepoints are extracted from the
% digi channel and time axis of the data is redefined such that t=0 is the
% start of the run
%
%%% INPUT %%%
%       ID         =  participant ID (e.g. '110001'); 
% Additional options can be specified in key-value pairs and can be:
%       'quality_check'    = 1 or 0. 1 for quality check during loading of data; 0 for no
%       quality check (default =0)
%       'vis'        =  1 or 0 for visualizing the trigger event of each
%       run (default = 1)
%
%%% OUTPUT %%%
%       run (structure) = structures for each poly5 file in FT format
%       containing the data (where t=0 is the start of the run).
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Get the options
qual_check = ft_getopt(varargin, 'quality_check', 0);
vis= ft_getopt(varargin, 'vis', 1);

%% Load in data
poly5=dir(fullfile(data_dir, ID, '110110 201*', 'Porti*', 'Porti*.Poly5'));
if isempty(poly5)
  warning('No poly5 files are found. Please make sure you are connected to the file server (data_dir)')
end
% exceptions
if strcmp(ID, '110004')
  warning('poly5-file number 6 was almost empty. Not using this file as a run')
  poly5=poly5([1:5 7]);
end
run=struct([]);
for i=1:length(poly5)
    fprintf('........processing run %d........ \n', i)
    filename=fullfile(poly5(i).folder, poly5(i).name);
    % read into fieldtrip
    cfg=[];
    cfg.channel=[2 4 5 33]; % only select channels RA, LA, LL and digi respectively
    cfg.dataset=filename; 
    cfg.feedback='no';
    data=ft_preprocessing(cfg);
    % rename labels
    data.label{1}='RA';
    data.label{2}='LA';
    data.label{3}='LL';
    cfg=[];
    cfg.channel=[1:3];
    data_leads_orig=ft_selectdata(cfg, data); % remove digi channel
    
    % re-reference the data to calculate the limb leads
    data_leads_init=data; 
    data_leads_init.trial{1}(1,:)=data.trial{1}(2,:)-data.trial{1}(1,:); % I=LA-RA
    data_leads_init.label{1}='I';
    data_leads_init.trial{1}(2,:)=data.trial{1}(3,:)-data.trial{1}(1,:);% II=LL-RA
    data_leads_init.label{2}='II';
    data_leads_init.trial{1}(3,:)=data.trial{1}(3,:)-data.trial{1}(2,:);% III=LL-LA
    data_leads_init.label{3}='III';
    cfg=[];
    cfg.channel=[1:3];
    data_leads_init=ft_selectdata(cfg, data_leads_init); % remove digi channel
    
    data_leads_aug=data;
    data_leads_aug.trial{1}(1,:)=data.trial{1}(1,:)-mean(data.trial{1}([2 3],:)) ; % aVR=RA-mean(LA+LL)
    data_leads_aug.label{1}='aVR';
    data_leads_aug.trial{1}(2,:)=data.trial{1}(2,:)-mean(data.trial{1}([1 3],:));% aVL=LA-mean(RA+LL)
    data_leads_aug.label{2}='aVL';
    data_leads_aug.trial{1}(3,:)=data.trial{1}(3,:)-mean(data.trial{1}([1 2],:));% aVF=LL-mean(LA+RA)
    data_leads_aug.label{3}='aVF';
    cfg=[];
    cfg.channel=[1:3];
    data_leads_aug=ft_selectdata(cfg, data_leads_aug); % remove digi channel
    
    % append raw data with  the limb leads data
    cfg=[];    
    data_leads=ft_appenddata(cfg, data_leads_orig, data_leads_init, data_leads_aug);
    
    % define triggers
    triggers=ft_read_event(filename, 'detectflank', 'up');
    if qual_check & length(triggers)>1
      warning('More than one event detected. Using the last event to redefine the time axis. Please check in the figure if this is correct.');
      figure; plot(data.time{1}, data.trial{1}(4,:));
      hold on; plot(triggers(end).sample/data_leads.fsample, 6, 'o');
      title('Please check whether the correct trigger event is detected. Press enter to continue.')
      pause;
      triggers=triggers(end);
    elseif length(triggers)>1
      warning('More than one event detected. Using the last event to redefine the time axis. Please check in the figure if this is correct.');
      triggers=triggers(end);
    end
    if vis
      figure; plot(data.time{1}, data.trial{1}(4,:));
      hold on; plot(triggers.sample/data_leads.fsample, 6, 'o');
    end
    
    % redefine time axis of data to the start of run (trigger --> t=0)
    cfg=[];
    cfg.offset=-triggers.sample;
    data_ses=ft_redefinetrial(cfg, data_leads);
    
    % browse data; check quality and normality of ECG
    if qual_check
        cfg=[];
        cfg.channel={'RA', 'LA', 'LL', 'I', 'II', 'III', 'aVR', 'aVL', 'aVF'};
        cfg.blocksize=10;
        cfg.demean='yes';
        cfg.viewmode='vertical';
        cfg.ylim=[-1000 1000];
        int=ft_databrowser(cfg, data_ses); % select first PQ-interval, second QRS-duration, third QT-interval, last RR interval
        
        % check conduction intervals
        intervals=int.artfctdef.visual.artifact;
        if ~isempty(intervals)
            
            RR=(intervals(4,2)-intervals(4,1))/data_leads.fsample;
            PQ=(intervals(1,2)-intervals(1,1))/data_leads.fsample; % PQ interval in seconds
            QRS=(intervals(2,2)-intervals(2,1))/data_leads.fsample;
            QTc=(intervals(3,2)-intervals(3,1))/sqrt(RR)/data_leads.fsample;
            
            if PQ<0.12 | PQ>0.2
                warning(sprintf('aberrant PQ interval of %.3f seconds (normal [0.120-0.200 msec])', PQ))
            else
                fprintf('Normal PQ interval of %.3f seconds \n', PQ)
            end
            if QRS>0.12
                warning(sprintf('aberrant QRS duration of %.3f seconds (normal < 0.120 msec)', QRS))
            else
                fprintf('Normal QRS duration of %.3f seconds \n', QRS)
            end
            if QTc>0.460
                warning(sprintf('aberrant QTc interval of %.3f seconds (normal < 0.450 msec)', QTc))
            else
                fprintf('Normal QTc interval of %.3f seconds \n', QTc)
            end
            fprintf('Heart rate calculated from RR interval is %.0f bpm \n', 60/RR)
        end
    end
     
     % save new data structure in the big run structure (containing all
     % poly5 files)
     run(i).data_ECG=data_ses;
     
end

