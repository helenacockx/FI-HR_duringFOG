%% script for comparing FOG annotations
% This scipt combines FOG annotations into a new table 'Annotations_combined_PD-*ID*.tsv'
% The script also displays the cohen's kappa correlation coefficient and
% Spearman's correlation.
%
% Dependencies: checkFOGevents.m, combineFOGannot.m, backcorrection.m,
% kappacoefficent.m, kappacoefficentall.m, spearman.m

%% settings
% ! make sure that you are connected with the file server when accessing
% the raw data
clear all; close all;
data_dir = '\\mbneufy4-srv.science.ru.nl\mbneufy4\FOG_annotation\datasets\Brainwave\Experiment2';
annot_dir = '\\mbneufy4-srv.science.ru.nl\mbneufy4\FOG_annotation\annotations\Brainwave\experiment2';
scripts_dir = 'F:\Brainwave_exp2\scripts\final\B.compareFOG_main';
proc_dir= 'F:\Brainwave_exp2\processed\final'; 

addpath(genpath(scripts_dir));
cd(proc_dir)

% subject ID's 
for i=1:16
  ID{i}=sprintf('1100%.2d', i);
end

%% Combine FOG annotations
subjects=[1:16];

% loop over subjects
for i=subjects
  sub(i).ID=ID{i};
  % check if all the annotations are correct and combine FOG_Triggers with
  % FOG_Types.
  [sub(i).FOG_events, sub(i).rater]=checkFOGevents(ID{i}, data_dir, annot_dir);
  if isempty(sub(i).FOG_events)
    continue
  end
  % combine the annotations of the two raters and check for agreement
  [sub(i).FOG_events, sub(i).info]=combineFOGannot(sub(i).FOG_events); % add .combined to structure
  % backcorrection for each annotator
  for r=1:2 % rater 1 and 2
    bc_FOG_events{r}=backcorrection(sub(i).FOG_events.combined, [sub(i).rater(r).sessions.corr], [sub(i).rater(r).sessions.offset]);
  end
  % combine backcorrected timestamps in one table
  FOG_events_combined=table(bc_FOG_events{1}.FOG_Trigger, bc_FOG_events{1}.FOG_Type, sub(i).FOG_events.combined.begin_time, sub(i).FOG_events.combined.end_time, bc_FOG_events{1}.begin_time, bc_FOG_events{1}.end_time, bc_FOG_events{2}.begin_time, bc_FOG_events{2}.end_time, bc_FOG_events{1}.duration,...
    bc_FOG_events{1}.session_number, bc_FOG_events{1}.file, bc_FOG_events{1}.NOTES_rater1, bc_FOG_events{1}.NOTES_rater2, bc_FOG_events{1}.check_trigger, bc_FOG_events{1}.check_type, bc_FOG_events{1}.agreement, bc_FOG_events{1}.rater,...
    'VariableNames', {'FOG_Trigger', 'FOG_Type', 'begin_time', 'end_time', sprintf('begin_time_%s', sub(i).rater(1).name), sprintf('end_time_%s', sub(i).rater(1).name),sprintf('begin_time_%s', sub(i).rater(2).name), sprintf('end_time_%s', sub(i).rater(2).name) 'duration', 'session_number', 'file', 'NOTES_rater1', 'NOTES_rater2', 'check_trigger', 'check_type', 'agreement', 'rater'});
  % write to .tsv-file (available in excel)
%   writetable(FOG_events_combined, fullfile(annot_dir, 'combined', sprintf('Annotations_combined_PD-%s.tsv',ID{i})), 'FileType', 'text', 'Delimiter', '\t');
  % calculate kappa coefficient
  sub(i).kappa=kappacoefficient(sub(i).FOG_events, sub(i).rater);
  % calculate kappa coefficient over all episodes instead of over all
  % patients
  kappa=kappacoefficientall(sub)  
end
% save('sub.mat', 'sub')

% plot kappa coefficient
figure; plot([sub.kappa]);
title('Cohens kappa coefficient over patients'); 
xlabel('patient number'); ylabel('cohens kappa')
meankappa=mean([sub.kappa]);
display(meankappa)

% calculate Spearman's correlation
[correlation] = HC_spearman(sub);
display(correlation)

%% calculate disagreement between trembling shuffling
disagree=0; n=0;
for i=1:16
  x=sum(sub(i).FOG_events.combined.agreement & contains(sub(i).FOG_events.combined.FOG_Type, 'Shuffling') & contains(sub(i).FOG_events.combined.FOG_Type, 'Trembling'));
  y=sum(sub(i).FOG_events.combined.agreement & contains(sub(i).FOG_events.combined.FOG_Type, 'Shuffling') & contains(sub(i).FOG_events.combined.FOG_Type, 'Akinesia'));
  disagree=disagree+x;
  n=n+sum(sub(i).FOG_events.combined.agreement & contains(sub(i).FOG_events.combined.FOG_Type, 'Shuffling'));
end
fprintf('%.0f%% of the annotated shuffling events were in disagreement \n', disagree/n*100)
