function data_epoch=define_FOGtrial(run)
%
% This function splits the derivative data in all the runs of one patient into
% trials as defined by trialfun_FOG: timelocked on the FOG/stop event and
% with a matrix trialinfo giving more information about the trials.
%
% Use as
%   [data_epoch]      = HC_FOGtrial(run, varargin)
%
% INPUT:
%       run    = structure of all the runs containing the data and
%       events
%
% OUTPUT
%       data_epoch   = the trials over all runs of that patient.
%       Trialinfo contains 5 additional columns:
%           1: FOG+ (1) or stop (0) or normal gait event (2) trial
%           2: trigger event: turn(1), narrow passage (2), starting
%           hesitation (3) or others (4)
%           3: delay between the trigger event and the FOG/stop event
%           4: FOG type: trembling (1), shuffling (2), akinesia (3), stop
%           trial (nan)
%           5: dual task: mono-task (0), cognitive dual-task (1), motor
%           dual-task (2), motor-cognitive dual-task (only PD1&2) (3)
%
% dependencies: trialfun_FOGtrial


%% Define the trials
% define trials, timelocked on the FOG/stop/normal gait event.
% trials also contain trialinfo (see OUTPUT)
tmp=struct([]); excl_total=0;
for i=1:length(run)
  fprintf('........FOG+ trials for %s........ \n', run(i).info.runname)
  [trl, excl]=trialfun_FOGtrial(run(i).events, run(i).variables.fsample, 'trial_exclusion', 'FOG' , 'shortFOG_exclusion', false);
  cfg=[];
  cfg.trl=trl;
  if isempty(cfg.trl)
    continue
  end
  tmp(i).data=ft_redefinetrial(cfg, run(i).variables);
  excl_total=excl_total+excl; % count excluded FOG trials
end


% append data into one data_epoch
tmp_cmp=[tmp.data]; % get rid of empty structures
data_epoch=tmp_cmp(1);
cfg=[];
cfg.keepsampleinfo='no';
for i=2:length(tmp_cmp)
    data_epoch=ft_appenddata(cfg, data_epoch, tmp_cmp(i));
end
n_FOG=length(find(data_epoch.trialinfo(:,1)==1));
fprintf('In total %d from the %d FOG episodes were excluded \n', excl_total, excl_total+n_FOG)

% remove trials with too many nans in heart rate data
cfg=[];
cfg.trials=true(1, length(data_epoch.trial));
for i=1:length(data_epoch.trial)
  if sum(isnan(data_epoch.trial{i}(1,:)))>3*data_epoch.fsample
    cfg.trials(i)=false;
  end
end
fprintf('removing %d nan FOG trials, %d nan stop trials, and %d normal gait event trials \n', sum(cfg.trials'==0 & data_epoch.trialinfo(:,1)==1),sum(cfg.trials'==0 & data_epoch.trialinfo(:,1)==0),sum(cfg.trials'==0 & data_epoch.trialinfo(:,1)==2))
data_epoch=ft_selectdata(cfg, data_epoch);
