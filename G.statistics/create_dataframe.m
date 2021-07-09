% script to average the data over 3-second windows (baseline, preFOG and
% FOG) of the cond_trials and save it in one big dataframe
subjects=[1:16];
triglookup={'turn', 'doorway'};
typelookup={'trembling', 'shuffling', 'akinesia'};
DTlookup={'nDT', 'cDT', 'mDT', 'cDT'}; % count mcDT as cDT (ID 1 & 2)
condlookup={'stop', 'FOG', 'trigger'};
dataframe=[];
tot_trial=1;
for j=subjects
    fprintf('\n \n <strong> ========== Subject %d ========== </strong> \n', j)
    id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', j));
    load(fullfile(id_folder, 'cond_trials.mat'));
    % only select trials with trigger turn/doorway
    cfg=[];
    cfg.trials=find(cond_trials.trialinfo(:,2)==1 | cond_trials.trialinfo(:,2)==2);
    cond_trials=ft_selectdata(cfg, cond_trials);
    % count number of data elements needed & create (empty) structures
    n=length(cond_trials.trial)*3; 
    pid=repelem(ID(j), n,1);
    trial=nan(n,1); % or create directly?
    HR=nan(n,1);
    HRs=nan(n,1);
    HRZ=nan(n,1);
    HRsZ=nan(n,1);
    HRCh=nan(n,1);
    FI_R=nan(n,1);
    mFI_R=nan(n,1);
    TPower_R=nan(n,1);
    motorband_R=nan(n,1);
    freezeband_R=nan(n,1);
    time=cell(n,1); % or create directly?
    trigger=cell(n,1);
    type=cell(n,1);
    DT=cell(n,1);
    condition=cell(n,1);
    idx=1;
    % average heart rate over time windows
    cfg=[]; cfg.channel={'heartrate'};  cfg.avgovertime='yes'; cfg.nanmean='yes';
    cfg.latency=[-6 -3];
    HR_baseline=ft_selectdata(cfg, cond_trials);
    cfg.latency=[-3 0];
    HR_preFOG=ft_selectdata(cfg, cond_trials);
    cfg.latency=[0 3];
    HR_FOG=ft_selectdata(cfg, cond_trials);
    % average power over time windows (2 sec. earlier)
    cfg=[]; cfg.channel={'FI_R', 'mFI_R', 'TPower_R', 'motorband_R', 'freezeband_R'};  cfg.avgovertime='yes'; cfg.nanmean='yes';
    cfg.latency=[-6 -3];
    Pow_baseline=ft_selectdata(cfg, cond_trials);
    cfg.latency=[-3 0];
    Pow_preFOG=ft_selectdata(cfg, cond_trials);
    cfg.latency=[0 3];
    Pow_FOG=ft_selectdata(cfg, cond_trials);
    idx=1;
    % loop over trials
    for t=1:length(cond_trials.trial)
      trial(idx:idx+2)=repelem(tot_trial, 3, 1); % for each new trial (also in new patient), use new trial number
      HR(idx:idx+2)=[HR_baseline.trial{t}(1,1); HR_preFOG.trial{t}(1,1); HR_FOG.trial{t}(1,1)];
      FI_R(idx:idx+2)=[Pow_baseline.trial{t}(1,1); Pow_preFOG.trial{t}(1,1); Pow_FOG.trial{t}(1,1)];
      mFI_R(idx:idx+2)=[Pow_baseline.trial{t}(2,1); Pow_preFOG.trial{t}(2,1); Pow_FOG.trial{t}(2,1)];
      TPower_R(idx:idx+2)=[Pow_baseline.trial{t}(3,1); Pow_preFOG.trial{t}(3,1); Pow_FOG.trial{t}(3,1)];
      motorband_R(idx:idx+2)=[Pow_baseline.trial{t}(4,1); Pow_preFOG.trial{t}(4,1); Pow_FOG.trial{t}(4,1)];
      freezeband_R(idx:idx+2)=[Pow_baseline.trial{t}(5,1); Pow_preFOG.trial{t}(5,1); Pow_FOG.trial{t}(5,1)];
      time(idx:idx+2)={'baseline'; 'preFOG'; 'FOG'};
      trigger(idx:idx+2)=repelem(triglookup(cond_trials.trialinfo(t,2)), 3,1);
      try
        type(idx:idx+2)=repelem(typelookup(cond_trials.trialinfo(t,4)), 3,1);
      catch
        type(idx:idx+2)=repelem(condlookup(cond_trials.trialinfo(t,1)+1), 3, 1); % use 'stop' or 'congr' or 'trigger' instead of nan 
      end
      DT(idx:idx+2)=repelem(DTlookup(cond_trials.trialinfo(t,5)+1), 3, 1); % starts with 0
      condition(idx:idx+2)=repelem(condlookup(cond_trials.trialinfo(t,1)+1), 3,1); % starts with 0
      idx=idx+3;
      tot_trial=tot_trial+1;
    end
    data_pid=table(pid, trial, HR, FI_R, mFI_R, TPower_R, motorband_R, freezeband_R, time, trigger, type, DT, condition);
    dataframe=[dataframe; data_pid];
end

writetsv(dataframe, fullfile(proc_dir, 'dataframe.tsv'))
save(fullfile(proc_dir, 'dataframe.mat'), 'dataframe')

