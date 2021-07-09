%% load the ECG data, accelerometer data and events and store in BIDS format


%% load ECG data and events
% specify the subjects you want to load the data for
subjects=[1:16];

for i=subjects
    fprintf('\n \n <strong> ========== Subject %d ========== </strong> \n', i)
    id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', i));
    if ~exist(id_folder)
      mkdir(id_folder);
    end
    run=LoadECGData(ID{i}, data_dir, 'quality_check', 0, 'vis', 0); % Load the ECG data of all the recordings and check quality:
    run=LoadEvents(run, ID{i}, annot_dir, data_dir); % add events to the runs
    save(fullfile(id_folder, 'run.mat'), 'run');
end

% remarks:
% From PD3 on: FOG_course_rapid_Dualcog --> FOG_course_Dualcog (so not
% rapid anymore) and FOG_course_dualmotorcog --> FOG_course_dualmotor (so
% no cognitive task during tray walk anymore).
%   - PD1: run 5 + 6 are empty; run 4 from 260 sec. on. Best lead =
%   II(III) (LL)
%   - PD2: bundel tak blok, lead II/LL beste. run 4 = kort; ook 5 data sessies en 4 annotatie sessies --> gebruik sessie
%   4 niet. run 3: some noise from sec. 127-180 (better in lead III/LL) and sec. 364-374.
%   run 5 (=run 4): noisy from sec 286-365. ==> eventually use lead
%   III/LL.
%   - PD3: good quality (all leads). Sometimes VES. run 6: sec.
%   3-13 + sec. 373-383: all limb leads except III are empty.
%   - PD4: lead I has best quality, other leads are quite noisy. VES are
%   quite small in lead I and might go underdetected. run 6: no start
%   trigger could be detected. Is also quite short. Also 7 poly5 files <> 6
%   video files => do not use the sixth poly5 file.
%   - PD5: best lead = II. run 1: bit noisy form sec. 139-142. run
%   4: noisy at sec.93-99. run 5: noisy from sec. 39-40; 66-70;
%   91-95;190-end (lead I is better here). run 6: noisy from sec. 98-
%   (I = better until sec. 198, again better at 374)
%   - PD6: run 2: only lead II/LL is fine from sec. 19-34 & sec. 173-206.
%   run 3: idem for se. 251- 259 & 276-282, etc. => use lead II/LL
%   - PD7: first grade AV block. Sometimes quite noisy, lead II (and
%   III)/LL
%   looks best.
%   - PD8: relatively good quality, lead II=best.
%   - PD9: relatively good quality, lead II=best.
%   - PD10: strongly deviated heart axis (to the left), regularly VES. lead
%   II/III is best 
%   - PD11: lead II is best. 
%   - PD12: lead I/LA is best. some unexpected movements in official 2 (259 &
%   291), 3 (94.5), 5 (70).
%   - PD13: lead II/LA (or I) is best. Tremer visible in ECG signal +-3-5 Hz
%   (or atrial flutter).
%   - PD14: good quality in all leads. Lead 1 is best.
%   - PD15: most runs drift but good quality in all channels. best lead
%   =I/II
%   - PD16: good quality in most channels. I/II is best.

%% apply acquired information: remove empty runs + select best lead
for i=subjects
  id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', i));
  load(fullfile(id_folder, 'run.mat'));
  run=runinfo(run, ID{i});
  save(fullfile(id_folder, 'run.mat'), 'run');
end

%% load accelerometer data and save in runs
subjects=[1:16];

for i=subjects
    fprintf('\n \n <strong> ========== Subject %d ========== </strong> \n', i)
    id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', i)); 
    load(fullfile(id_folder, 'run.mat'))
    run=LoadAcceleroData(run, ID{i}, data_dir, 'quality_check', 0, 'vis', 0); % Load the motion data of all the recordings and check quality:
    save(fullfile(id_folder, 'run.mat'), 'run');
end

% PD3: no signal in LF accelerometer
% PD5: weird fast waves during standing still at baseline L>R (tremor?)

%% store all data in BIDS format
subjects=[1:16];

for i=subjects
  for r=1:length(run)
    % only select raw data channels
    cfg=[];
    cfg.channel= {'RA', 'LA', 'LL'};
    ECGraw=ft_selectdata(cfg, run(r).data_ECG);
    
    cfg=[];
    cfg.channel= {'RF_X', 'RF_Y', 'RF_Z', 'LF_X', 'LF_Y', 'LF_Z'};
    accelraw=ft_selectdata(cfg, run(r).data_accelero);
    
    % append ECG with accelero data
    cfg=[];
    data_raw=ft_appenddata(cfg, ECGraw, accelraw);
    
    % convert to BIDS
    convert2bids(data_raw, run(r).events, i, r)
  end
end

% write *.json files at top level
writejson;
