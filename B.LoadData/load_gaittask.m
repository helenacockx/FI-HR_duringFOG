function [session_gaittask, session_AAS]=load_gaittask(ID, session, orig_name,  nsession, fsample, data_dir)

% internal check (exception: session 5 and 6 did not contain ECG data)
if nsession~=length(dir(fullfile(data_dir, ID, '*Session*'))) & ~strcmp(ID, '110001')
  error('%d text files and %d data sessions were found for this subject', length(dir(fullfile(data_dir, ID, '*Session*'))), nsession)
end

%% Gait_task
% read in .txt file
filename=fullfile(data_dir, ID, sprintf('%s_Session%d/%s_Session%d.txt', ID, session, ID, session)); % this is the .txt file for the current session
fileID=fopen(filename);
t=textscan(fileID, '%s %D %T %D %T', 'HeaderLines', 3);
fclose(fileID);
n=find(strcmp(t{1}, '----------AAS----------'))-1; % this the amount of tasks

% start of the video
start_video=t{3}(1);

% create empty structures
timestamp=nan(n, 1); end_time=nan(n,1); duration=nan(n,1); value=cell(n,1);

% loop over the gait tasks and collect info
for i=1:n
  timestamp(i)=seconds(t{3}(i)-start_video);
  end_time(i)=seconds(t{5}(i)-start_video);
  duration(i)=round((end_time(i)-timestamp(i))*fsample); % !in samples!
  switch char(t{1}(i))
    case 'StandStill'
      value{i}='Rest';
    case 'RapidTurn+AAS'
      value{i}='360spin_rapid_Dualcog';
    case 'RapidTurn'
      value{i}='360spin_rapid';
    case 'NormalWalk'
      value{i}='FOG_course';
    case 'NormalWalk+AAS'
      value{i}='FOG_course_Dualcog';
    case 'RapidWalk+AAS'
      value{i}='FOG_course_rapid_Dualcog';
    case 'TrayNormalWalk'
      value{i}='FOG_course_Dualmotor';
    case 'TrayWalk+AAS'
      value{i}='FOG_course_Dualmotorcog';
  end
end
type=cell(n,1);
type(:)={'Gait_task'};
file=cell(n,1);
file(:)={orig_name};

% generate a table
session_gaittask=table(type, value, timestamp, end_time, duration, file);

%% AAS task
% read in .txt file
filename=fullfile(data_dir, ID, sprintf('%s_Session%d/%s_Session%d.txt', ID, session, ID, session)); % this is the .txt file for the current session
fileID=fopen(filename);
t=textscan(fileID, '%s');
fclose(fileID);

% start of the video
start_video=datetime(t{1}{11}, 'InputFormat','HH:mm:ss', 'Format', 'HH:mm:ss.SSS') ;
        
% find the indexes of the AAS tasks
st=find(strcmp(t{1}, 'Time')); % after this word a bunch of timestamps are give
idx=[];
for i=1:length(st)
  if i==length(st)
    idx=[idx st(i)+1:3:length(t{1})-2];
  else
    idx=[idx st(i)+1:3:st(i+1)-5];
  end
end

% collect the information of each AAS task
n=length(idx);
timestamp=nan(n, 1); value=cell(n,1);
for i=1:n
  timestamp(i)=seconds(datetime(t{1}{idx(i)+2}, 'InputFormat', 'HH:mm:ss', 'Format', 'HH:mm:ss.SSS')-start_video);
  if any(strcmp(t{1}{idx(i)}, {'1', '2'}))
    value{i}='congruent';
  elseif any(strcmp(t{1}{idx(i)}, {'3', '4'}))
    value{i}='incongruent';
  end
end
type=cell(n,1);
type(:)={'AAS_task'};
end_time=timestamp;
duration=zeros(n,1);
file=cell(n,1);
file(:)={orig_name};

% convert to table
session_AAS=table(type, value, timestamp, end_time, duration, file);
