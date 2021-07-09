% script to calculate the characteristics of the FOG events and their
% distribution over the participants, FOG types, FOG triggers, and DT
% conditions.

%% load all FOG_events
FOG_Trig_all=[]; FOG_Type_all=[];
for i=1:16
  fprintf('\n \n <strong> ========== Subject %d ========== </strong> \n', i)
  id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', i));
  load(fullfile(id_folder, 'run.mat'));
  for s=1:length(run)
    duration_sec=num2cell([run(s).events.end_time]-[run(s).events.timestamp]);
    [run(s).events.duration_sec]=deal(duration_sec{:}); % add duration in seconds
    [run(s).events(:).ID]=deal({sprintf('%d', i)});
    FOG_Trig_run=run(s).events(contains({run(s).events.type}, 'FOG_Trigger'),:);
    FOG_Type_run=run(s).events(contains({run(s).events.type}, 'FOG_Type'),:);
    Gait_tasks=run(s).events(strcmp({run(s).events.type}, 'Gait_task'),:);
    % find dual-task condition
    if isempty(FOG_Trig_run)
      continue
    else
      for k=1:length(FOG_Trig_run)
        try
          task=Gait_tasks(find(FOG_Trig_run(k).sample>[Gait_tasks.sample] & FOG_Trig_run(k).sample<[Gait_tasks.sample]+[Gait_tasks.duration])).value;
        catch
          warning('stop event fell outside gait_task. Using previous gait_task to determine dual task condition');
          task=Gait_tasks(find(FOG_Trig_run(k).sample>[Gait_tasks.sample],1, 'last')).value;
        end
        if contains(task, 'Dualmotorcog') % only patient 1&2 (don't have mDT alone --> mDT)
          FOG_Trig_run(k).DT={'mDT'};
        elseif contains(task, 'Dualmotor')
          FOG_Trig_run(k).DT={'mDT'};
        elseif contains(task, 'Dualcog')
          FOG_Trig_run(k).DT={'cDT'};
        else
          FOG_Trig_run(k).DT={'nDT'};
        end
      end
    end
    FOG_Trig_all=[FOG_Trig_all; FOG_Trig_run];
    FOG_Type_all=[FOG_Type_all; FOG_Type_run];
  end
end
% convert to table
FOG_Trig_all=struct2table(FOG_Trig_all);
FOG_Type_all=struct2table(FOG_Type_all);

%% general variables of FOG events
total_number_FOG=height(FOG_Trig_all)
median_duration_FOG=median(FOG_Trig_all.duration_sec) % in seconds
iqr_duration_FOG=prctile(FOG_Trig_all.duration_sec, [25 75])
min_duration_FOG=min(FOG_Trig_all.duration_sec)
max_duration_FOG=max(FOG_Trig_all.duration_sec)

%% boxplots of FOG durations
figure; boxplot(FOG_Trig_all.duration_sec, FOG_Trig_all.ID, 'PlotStyle', 'traditional', 'Colors','k', 'Symbol', 'k.', 'DataLim',[0 75], 'width', 0.8)
 xlabel('participant'); ylabel('FOG duration (s)')
 title('FOG duration by participant')
 set(gca, 'Fontsize', 40);
 set(findobj(gca,'type','line'),'linew',3)
saveas(gcf, fullfile(fig_dir, 'FOG_variables','FOGduration_byPatient.eps'))

%% bar charts showing differences between each patient
% by trigger
load('sub.mat')
nmb_trig=nan(16,4); 
IDshort=arrayfun(@(x) sprintf('%d',x), [1:16], 'UniformOutput', false);
for i=1:16
  idx_turn= find(strcmp(FOG_Trig_all.ID, IDshort(i)) & contains(FOG_Trig_all.value, {'360', '180'}));
  idx_door=find(strcmp(FOG_Trig_all.ID, IDshort(i)) & contains(FOG_Trig_all.value, 'Doorway'));
  idx_sh=find(strcmp(FOG_Trig_all.ID, IDshort(i)) & contains(FOG_Trig_all.value, 'SH'));
  idx_other=find(strcmp(FOG_Trig_all.ID, IDshort(i)) & (contains(FOG_Trig_all.value, {'Target', 'Dual'}) | strcmp(FOG_Trig_all.value, 'FOG')));
  nmb_trig(i,1)=length(idx_turn);
  nmb_trig(i,2)=length(idx_door);
  nmb_trig(i,3)=length(idx_sh);
  nmb_trig(i,4)=length(idx_other);
end
% plot
figure;
bar(nmb_trig, 'stacked'); % or: bar(nmb_trig);
ylim([0 100]); xticks([1:16]);
xlabel('participant'); ylabel('number of FOG')
legend({'FOG turn', 'FOG narrow passage','FOG starting hesitation', 'FOG others'}, 'Location', 'north', 'orientation', 'horizontal', 'FontSize', 30)
title('FOG events by participant and by trigger')
set(gca, 'Fontsize', 40);
saveas(gcf, fullfile(fig_dir, 'FOG_variables','NumberFOGs_byPatient_byTrigger.jpg'))
sum(nmb_trig)/total_number_FOG*100

% by type
nmb_type=nan(16,3); 
for i=1:16
  idx_tremb= find(strcmp(FOG_Trig_all.ID, IDshort(i)) & strcmp(FOG_Type_all.value, 'Trembling'));
  idx_akin=find(strcmp(FOG_Trig_all.ID, IDshort(i)) & strcmp(FOG_Type_all.value, 'Akinesia'));
  idx_shuf=find(strcmp(FOG_Trig_all.ID, IDshort(i)) & strcmp(FOG_Type_all.value, 'Shuffling'));
  nmb_type(i,1)=length(idx_tremb);
  nmb_type(i,2)=length(idx_akin);
  nmb_type(i,3)=length(idx_shuf);
end
% plot
figure;
bar(nmb_type, 'stacked'); % or: bar(nmb_trig);
ylim([0 100]); xticks([1:16]);
xlabel('participant'); ylabel('number of FOG')
legend({'trembling', 'akinesia','shuffling'},'Location', 'north', 'orientation', 'horizontal', 'FontSize', 30)
title('FOG events by participant and by type')
set(gca, 'Fontsize', 40);
saveas(gcf, fullfile(fig_dir, 'FOG_variables','NumberFOGs_byPatient_byType.jpg'))
sum(nmb_type)/total_number_FOG*100

% by DT
nmb_DT=nan(16,3);
for i=1:16
  idx_nDT= find(strcmp(FOG_Trig_all.ID, IDshort(i)) & contains(FOG_Trig_all.DT, 'nDT'));
  idx_cDT=find(strcmp(FOG_Trig_all.ID, IDshort(i)) & contains(FOG_Trig_all.DT, 'cDT'));
  idx_mDT=find(strcmp(FOG_Trig_all.ID, IDshort(i)) & contains(FOG_Trig_all.DT, 'mDT'));
  nmb_DT(i,1)=length(idx_nDT);
  nmb_DT(i,2)=length(idx_cDT);
  nmb_DT(i,3)=length(idx_mDT);
end
% plot
figure;
bar(nmb_DT, 'stacked'); % or: bar(nmb_trig);
ylim([0 100]); xticks([1:16]);
xlabel('participant'); ylabel('number of FOG')
legend({'noDT', 'cDT', 'mDT'},'Location', 'north', 'orientation', 'horizontal', 'FontSize', 30)
title('FOG events by participant and by DT')
set(gca, 'Fontsize', 40);
saveas(gcf, fullfile(fig_dir, 'FOG_variables','NumberFOGs_byPatient_byDT.jpg'))
sum(nmb_DT)/total_number_FOG*100

