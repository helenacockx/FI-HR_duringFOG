function [FOG_events, rater]=checkFOGevents(ID, data_dir, annot_dir)
% this function loads the FOG annotations of the two raters, performs some
% internal checks and saves the events in the correct format

%% Initialization
annotators={'Wouter', 'Asra'}; % names of the two annotators

%% load annotations for this patient
  fprintf('\n========== PD_%s ========== \n', ID);
  % load annotations
  % rater 1
    rater(1).name=annotators{1};
    opts=detectImportOptions(fullfile(annot_dir, annotators{1}, sprintf('Annotations_%s_PD1-16_30062020.tsv', annotators{1})), 'FileType', 'text');
    opts.SelectedVariableNames={'Var1', 'Var3', 'Var5', 'Var7', 'Var8', 'Var9'};
    rater(1).annotations=readtable(fullfile(annot_dir, annotators{1}, sprintf('Annotations_%s_PD1-16_30062020.tsv', annotators{1})), opts);
    rater(1).annotations.Properties.VariableNames={'tier', 'begin_time', 'end_time', 'duration', 'annotation', 'file'};
    rater(1).annotations=rater(1).annotations(startsWith(rater(1).annotations.file, sprintf('PD_%s', ID)), :); % only for this patient
  % rater2
    rater(2).name=annotators{2};
    opts=detectImportOptions(fullfile(annot_dir, annotators{2}, sprintf('Annotations_%s_PD1-16_30062020.tsv', annotators{2})), 'FileType', 'text');
    opts.SelectedVariableNames={'Var1', 'Var3', 'Var5', 'Var7', 'Var8', 'Var9'};
    rater(2).annotations=readtable(fullfile(annot_dir, annotators{2}, sprintf('Annotations_%s_PD1-16_30062020.tsv', annotators{2})), opts);
    rater(2).annotations.Properties.VariableNames={'tier', 'begin_time', 'end_time', 'duration', 'annotation', 'file'};
    rater(2).annotations=rater(2).annotations(startsWith(rater(2).annotations.file, sprintf('PD_%s', ID)), :); % only for this patient


% internal checks
if length(unique(rater(1).annotations.file))~= length(unique(rater(2).annotations.file))
  warning('The two annotation files do not have the same number of sessions: %d annotation sessions for %s and %d annotation sessions for %s.', length(unique(rater(1).annotations.file)), rater(1).name, length(unique(rater(2).annotations.file)), rater(2).name)
  FOG_events=struct([]);
  return
end
if any(~strcmp(unique(rater(1).annotations.file), unique(rater(2).annotations.file)))
  warning('The two annotation files do not have the same name');
  FOG_events=struct([]);
  return
end

%% loop over sessions
% sessions as named by the annotators
session_names=unique(rater(1).annotations.file);
training_names=session_names(contains(session_names, 'Training')); % names of training sessions
n_training=length(training_names); % number of training sessions
official_names=session_names(contains(session_names, 'Official')); % names of official sessions
n_official=length(official_names); % number of official sessions
% sort with first training trials and than official sessions
session_names={training_names{1:end}, official_names{1:end}}';

t=1;
for i=1:length(session_names)
  fprintf('..........%s..........\n', session_names{i})
  % name of the session as named in the textgrid files
  orig_name=session_names{i};
  if contains(session_names{i}, 'Training')
    tmp_str=strsplit(char(orig_name), {'_', '-', '.'});
    name_session=[tmp_str{3} '_Trial_' tmp_str{4}];
  else
    tmp_str=strsplit(char(orig_name), {'_','-', '.'});
    name_session=[tmp_str{3} '_Session_' tmp_str{4}];
  end
  
  % select corresponding textGrid file
  textgrid=dir(fullfile(data_dir, ID, 'Videos', 'Camera1', sprintf('%s.TextGrid', name_session)));
  % read in the textGrid file
  fileID=fopen(fullfile(textgrid.folder, textgrid.name));
  text=textscan(fileID, '%s %s %f', 'HeaderLines', 19);
  fclose(fileID);
  offset_video=text{3}(1); % the offset of the video is the start of the first beep (in seconds)
  session_duration=text{3}(2)-text{3}(1);
  if isnan(offset_video)
    warning('the offset of the video could not be determined properly from the Textgrid file')
  end
  
  % for each annotator...
  for r=1:2
    % collect only events of this session
    rater(r).sessions(i).name=orig_name;
    rater(r).sessions(i).duration=session_duration;
    rater(r).sessions(i).events=rater(r).annotations(find(strcmp(rater(r).annotations.file, orig_name)),:);
    
    % compare offset of the video with the annotator-specific offset (corresponds to the begin_time of the Gait_task 'Rest')
    % and correct timestamps for differences between those offsets. (so
    % onset is relative to the start of the video)
    rater(r).sessions(i).offset=rater(r).sessions(i).events.begin_time(find(strcmp('Rest', rater(r).sessions(i).events.annotation)&strcmp(orig_name, rater(r).sessions(i).events.file)));
    rater(r).sessions(i).corr= rater(r).sessions(i).offset-offset_video;
    
    % internal checks
    if isempty(rater(r).sessions(i).offset)
      warning('The annotator specific offset for %s could not be determined since there was no Gait_task Rest in the annotations for rater %s. Please check this before preceding.', orig_name, rater(r).name)
      break
    end
    if rater(r).sessions(i).corr > 1
      warning('The offsets of annotator %s and the offsets from the TextGrid-file in %s differed more than 1 sec. Please check what the problem is (camera 1 = master?, correct beep was detected with TextGrid?)', rater(r).name, orig_name)
      break
    end
    if r==2 && abs(rater(1).sessions(i).offset-rater(2).sessions(i).offset)>1
      warning('the offsets for the two annotators in %s differed more than 1 sec. Possibly camera 1 was not used as master. Please, check what the problem is', orig_name)
      break
    end
    
    % correction --> not needed, because when exporting, the master media
  % time offset is already added
  rater(r).sessions(i).events_corr=rater(r).sessions(i).events;
%     rater(r).sessions(i).events_corr=rater(r).sessions(i).events;
%     rater(r).sessions(i).events_corr.begin_time=rater(r).sessions(i).events.begin_time-rater(r).sessions(i).corr;
%     rater(r).sessions(i).events_corr.end_time=rater(r).sessions(i).events.end_time-rater(r).sessions(i).corr;
    
    % combine FOG_Trigger, FOG_Type and NOTES with the same timestamp
    FOG_trig=rater(r).sessions(i).events_corr(find(strcmp(rater(r).sessions(i).events_corr.tier, 'FOG_Trigger')),:);
    FOG_type=rater(r).sessions(i).events_corr(find(strcmp(rater(r).sessions(i).events_corr.tier, 'FOG_Type')),:);
    NOTES=rater(r).sessions(i).events_corr(find(strcmp(rater(r).sessions(i).events_corr.tier, 'NOTES')), :);
    % internal checks
    if height(FOG_trig)~=height(FOG_type)
      warning('In %s from annotator %s %d FOG_Triggers and %d FOG_Types were found. Please check if an annotation is missing', orig_name, rater(r).name, height(FOG_trig), height(FOG_type));
      break
    elseif any(abs((FOG_trig{:,[2:4]}-FOG_type{:, [2:4]}))>0.1, 'all')
      warning('The timestamps of some of the FOG_Triggers and the FOG_Types differed with more than 100 msec. Please check the following FOGs for annotator', rater(r).name)
      [idx_r, idx_c]=find(abs((FOG_trig{:,[2 3]}-FOG_type{:, [2 3]}))>0.1)
      wrong=table(FOG_trig(unique(idx_r), [5 2:3]), FOG_type(unique(idx_r), [5 2:3]), FOG_trig(unique(idx_r), 6), 'VariableNames', {'FOG_Trigger', 'FOG_Type', 'file'});
      % perform backcorrrection to obtain annotator specific timestamps
      wrong.FOG_Trigger{:,[2 3]}=wrong.FOG_Trigger{:,[2 3]}+rater(r).sessions(i).corr-rater(r).sessions(i).offset;
      wrong.FOG_Type{:,[2 3]}=wrong.FOG_Type{:,[2 3]}+rater(r).sessions(i).corr-rater(r).sessions(i).offset;
      display(wrong)
      break
    end
    % combine FOG_Trigger and FOG_type in one table and add column for session number and notes
    FOG_events=table(FOG_trig.annotation, FOG_type.annotation, FOG_trig.begin_time, FOG_trig.end_time, FOG_trig.duration, i*ones(height(FOG_trig),1), FOG_trig.file, cell(height(FOG_trig),1), 'VariableNames', {'FOG_Trigger', 'FOG_Type', 'begin_time', 'end_time', 'duration', 'session_number', 'file', 'NOTES'});
    % put notes in the same table form
    NOTES=table(NOTES.tier, NOTES.tier, NOTES.begin_time, NOTES.end_time, NOTES.duration, i*ones(height(NOTES),1), NOTES.file, NOTES.annotation, 'VariableNames', {'FOG_Trigger', 'FOG_Type', 'begin_time', 'end_time', 'duration', 'session_number', 'file', 'NOTES'});
    % add notes to the FOG_events
    for n=1:height(NOTES)
      % find the notes that are similar to the FOG_events (i.e. differ by
      % max 100 msec) and add them as note. Else add the notes as a new
      % line to the FOG_events
      note_idx=find(abs(FOG_events{:,3}-(NOTES{n,3}))<0.1 & abs(FOG_events{:,4}-(NOTES{n,4}))<0.1);
      if ~isempty(note_idx)
        FOG_events.NOTES(note_idx)=NOTES.NOTES(n);
      else
        FOG_events=[FOG_events; NOTES(n,:)];
      end
    end
    
    % sort the FOG_events on ascending begin_time 
    FOG_events=sortrows(FOG_events, 3);
    
    % store FOG_events for this annotator
    try 
      rater(r).FOG_events=[rater(r).FOG_events; FOG_events];
    catch
      rater(r).FOG_events=FOG_events;
    end
  end
end

%% combine FOG_events from the two raters
clear FOG_events
try FOG_events.rater1=rater(1).FOG_events;
  FOG_events.rater1=rater(1).FOG_events;
catch FOG_events.rater1=[];
end
try FOG_events.rater2=rater(2).FOG_events;
  FOG_events.rater2=rater(2).FOG_events;
catch FOG_events.rater2=[];
end
