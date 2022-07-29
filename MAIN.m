%% MAIN SCRIPT
proc_dir= 'F:\Brainwave_exp2\processed\final'; 
scripts_dir = 'F:\Brainwave_exp2\scripts\final\';
data_dir = '\\mbneufy4-srv.science.ru.nl\mbneufy4\FOG_annotation\datasets\Brainwave\Experiment2';
annot_dir = '\\mbneufy4-srv.science.ru.nl\mbneufy4\FOG_annotation\annotations\Brainwave\experiment2';
fig_dir='F:\Brainwave_exp2\figures\';

addpath(genpath(scripts_dir));
cd(proc_dir);

% subject ID's 
for i=1:16
  ID{i}=sprintf('1100%.2d', i);
end


%% A. COMPARE FOG ANNOTATIONS
% 1. run script to combine FOG annotations into a new table 'Annotations_combined_PD-*ID*.tsv'
compareFOG_main;

% 2. Discuss the combined annotations when agreement=0 or check_trigger/check_type=1 and
% store this in a new table 'Annotations_agreed_PD-*ID*.tsv' where a new column 'consensus' is added with 1 for agreed FOG and 0 for agreed non FOG.
% This will be used by LoadEvents.m in a later stap.

%% B. LOAD DATA & EVENTS, AND STORE IN BIDS FORMAT
LoadData;

%% C. ANALYZE FOG EVENTS
FOGvariables;

%% D. DATA PREPROCESSING
data_preprocessing;

%% E. EPOCHING
% epoch the data of each participant in conditions 'FOG', 'stop'
% and 'normal gait event'.
subjects=[1:16];
for i=subjects
  fprintf('\n \n <strong> ========== Subject %d ========== </strong> \n', i)
    id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', i));
    load(fullfile(id_folder, 'run.mat'));
    cond_trials=define_FOGtrial(run);
    save(fullfile(id_folder, 'cond_trials.mat'), 'cond_trials')
end

%% F. TIMELOCK ANALYSIS
close all
subjects=[1:4 6 7 9:16];
conditions={'akinesia'}; 
variables={'motorband_R', 'freezeband_R'};
for c=1:length(conditions)
  clear condFOG condStop condTrig
  [condFOG, condStop, condTrig]=timelockCond(proc_dir, subjects, conditions{c}, variables, 'vis', 1, 'save_fig', 0, 'baseline', [-6 -3]);
  grandaverageCond(condFOG, condStop, condTrig, subjects, conditions{c}, variables, 'save_fig', 0, 'baseline', [-6 -3]);
end

%% E. STATISTICS
% average the data over 3-second windows (baseline, preFOG and
% FOG) of the cond_trials and save it in one big dataframe to export to
% Rstudio
create_dataframe;

% perform linear mixed models in Rstudio with script statistics_final.R