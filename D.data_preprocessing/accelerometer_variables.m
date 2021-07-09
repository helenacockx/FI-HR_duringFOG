function [run] = accelerometer_variables(run, varargin)
%
% This function procesrun the raw accelerometer data and derives the motor
% related variables like the freezing index.
%
% Use as
%   [run]    = accelerometer_variables(run, varargin)
%
% INPUT:
%       run    = run structure holding the raw data in
%       data_accelero
% Additional options can be specified in key-value pairs and can be:
%       'vis' = 1 or 0 for visualizing some of the calculated variables
%       together with the heart rate data with ft_databrowser
%
% OUTPUT
%       [run]  = run structure with the new motor variables added
%       to 'variables'
%
% dependencies: calculate_FI
%% Get the options
vis= ft_getopt(varargin, 'vis', 1);

for j=1:length(run)
  %% gather the data
    data_run=run(j).data_accelero;
    
    %% calculate freeze index (~>  Moore et al)
    % right foot
    [FI_RF, freezeband_RF, motorband_RF, TPower_RF]=calculate_FI(data_run, 'RF_Y');
   
    % left foot
    [FI_LF, freezeband_LF, motorband_LF, TPower_LF]=calculate_FI(data_run, 'LF_Y');
    
    % 'modified' FI with  TPower threshold (see Bachlin et al, 2009)
    TPThr_R=nanmean(TPower_RF(1:10*data_run.fsample))+nanstd(TPower_RF(1:10*data_run.fsample)); % see Capecci et al, 2016 (first 10 seconds of run = rest)
    TPThr_L=nanmean(TPower_LF(1:10*data_run.fsample))+nanstd(TPower_LF(1:10*data_run.fsample));
    mFI_RF=FI_RF;
    idx=find(TPower_RF<TPThr_R); 
    mFI_RF(idx)=0; 
    mFI_LF=FI_LF;
    idx=find(TPower_LF<TPThr_L); 
    mFI_LF(idx)=0; 

     %% save new variables in the variables structure
     run(j).variables.label(2:11,1)={'FI_R', 'FI_L', 'mFI_R', 'mFI_L', 'TPower_R', 'TPower_L', 'motorband_R', 'motorband_L', 'freezeband_R', 'freezeband_L'};
     run(j).variables.trial{1}(2:11,:)=[FI_RF; FI_LF; mFI_RF; mFI_LF; TPower_RF; TPower_LF; motorband_RF; motorband_LF; freezeband_RF; freezeband_LF];
     
     %% visualize
     if vis
     cfg=[];
     cfg.channel={'FI_R', 'mFI_R', 'freezeband_R', 'motorband_R', 'TPower_R'};
     cfg.blocksize=60;
     cfg.demean='yes';
     cfg.viewmode='vertical';
     cfg.event=run(j).events(find(ismember({run(j).events.type}, {'Gait_events', 'FOG_Trigger'}))); % only plot the FOG_Triggers and the Gait_events
     cfg.plotevents='yes';
     cfg.ploteventlabels='colorvalue';
%      cfg.mychan={'heartrate'};
%      cfg.mychanscale=[20];
     cfg.ylim=[-10 10];
     ft_databrowser(cfg, run(j).variables);
     end

end

