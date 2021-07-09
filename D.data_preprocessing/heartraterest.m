function [HR, HRV]=heartraterest(run)
% calculates the heart rate and heart rate variability for each participant
% during the resting period

fs=run(1).variables.fsample;
HR_chan=find(strcmp(run(1).variables.label, 'heartrate'));
% get heart rate data of all resting periods
HR_rest=[]; HRV_rest=[];
for j=1:length(run)
  rest=find(strcmp({run(j).events.type}, 'Gait_task') & strcmp({run(j).events.value}, 'Rest'));
  cfg=[];
  cfg.begsample=run(j).events(rest).sample;
  cfg.endsample=cfg.begsample+run(j).events(rest).duration;
  rest_trial=ft_redefinetrial(cfg, run(j).variables);
  HR_rest=[HR_rest nanmean(rest_trial.trial{1}(1,:))];
  HRV_rest=[HRV_rest nanstd(rest_trial.trial{1}(1,:))/nanmean(rest_trial.trial{1}(1,:))*100];
end
  
HR=mean(HR_rest);
HRV=mean(HRV_rest);