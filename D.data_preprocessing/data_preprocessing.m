% script to preproces the ECG and accelerometer data to variables that were
% used for the analysis (i.e., heart rate and FI)
%
% dependencies: heartrate.m, heartraterest.m, variables_accelerometer.m,
% variables_Zscore.m

%% 1. Calculate heart rate
% calculate heartrate and save in run.variables
% make sure you are on branch absoluteZ of fieldtrip!
subjects=[1:16];
for i=subjects
  fprintf('\n \n <strong> ========== Subject %d ========== </strong> \n', i)
    id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', i));
    load(fullfile(id_folder, 'run.mat'));
    run=heartrate(run, 'vis_PT', 0, 'vis', 0);
    save(fullfile(id_folder, 'run.mat'), 'run');
end

% calculate mean heart rate during resting period
HR=nan(16,1); HRV=nan(16,1);
subjects=[1:16];
for i=subjects
    fprintf('\n \n <strong> ========== Subject %d ========== </strong> \n', i)
     id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', i));
    load(fullfile(id_folder, 'run.mat'));
    [HR(i), HRV(i)]=heartraterest(run);
end  
fprintf('The median heart rate during rest was %f (range %f - %f) \n', nanmedian(HR), min(HR), max(HR))
fprintf('The median heart rate variability during rest was %f (range %f - %f) \n', nanmedian(HRV), min(HRV), max(HRV))
quantile(HR, [0.25 0.75])
quantile(HRV, [0.25 0.75])

%% 2. calculate variables based on the accelerometer data (FI)
subjects=[1:16];
for i=subjects
    fprintf('\n \n <strong> ========== Subject %d ========== </strong> \n', i)
    id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', i)); 
    load(fullfile(id_folder, 'run.mat'))
    run=accelerometer_variables(run, ID{i}, data_dir, 'quality_check', 0, 'vis', 0); % Load the motion data of all the recordings and check quality:
    save(fullfile(id_folder, 'run.mat'), 'run');
end

%% 3. calculate Z-scores of variables over all runs and create histograms
subjects=[1:16];
for i=subjects
    fprintf('\n \n <strong> ========== Subject %d ========== </strong> \n', i)
    id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', i)); 
    load(fullfile(id_folder, 'run.mat'))
    run=Zscore_variables(run, 'vis',1);
    save(fullfile(id_folder, 'run.mat'), 'run');
end