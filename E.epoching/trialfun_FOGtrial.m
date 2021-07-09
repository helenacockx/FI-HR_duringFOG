function [trl, excl] = trialfun_FOG(events, fsample, varargin)

% TRIALFUN_FOGTRIAL is trialfun function to create trials around the FOG onsets
% (FOG+),stop_walking onsets (FOG-) or normal gait events (FOG-) with 15 seconds pre and 15 seconds post
% the onset. Input are the events that are generated for each run and the sample frequency of the data.
% Output is a trl matrix with a trlinfo column for FOG_info (1=FOG+, 0=FOG-, 2=normal gait event),
% a column for the trigger (turn = 1, narrow_passage = 2, starting
% hesitation = 3, others = 4),
% a column for the delay between the trigger onset and the FOG onset,
% a column for the FOG type (trembling = 1, shuffling = 2, akinesia = 3, stop trial/normal gait event = nan),
% and a column for the dual task condition (no dual task = 0, cognitive dual task =1, motor dual
% task = 2, cognitive and motor dual task =3 (only PD1&2)).
% Additional option:
% 'trial_exclusion' = 'FOG', or 'stop', or 'FOG&stop' for exclusion of trials that were
% preceded by a FOG/stop event within 6 seconds (default = 'FOG')
% 'shortFOG_exclusion = true or false for exclusions of FOGs < 3 sec
% duration. (default = false)

% See also FT_DEFINETRIAL, FT_PREPROCESSING

%% Get the options
exclusion=ft_getopt(varargin, 'trial_exclusion', 'FOG');
if contains(exclusion, 'FOG')
  exclusion_FOG=true;
else 
  exclusion_FOG=false;
end
if contains(exclusion, 'stop')
  exclusion_stop=true;
else 
  exclusion_stop=false;
end

exclusion_short = ft_getopt(varargin, 'shortFOG_exclusion', 0);

%% define trials around the FOG events
excl=0; % count the excluded FOG trials
if ~isempty(events) && any(strcmp('FOG_Trigger', {events.type}))
  FOG_events=events(find(strcmp('FOG_Trigger', {events.type})));
  Gait_tasks=events(find(strcmp('Gait_task', {events.type})));
  stops= events(find(strcmp({events.value}, 'stop_walking')));
%   stops= events(find(strcmp({events.value}, 'start_walking'))); % if there was a stop walking, it starts again with a start walking
  trl           = [];
  onset_sample  = [FOG_events.sample];
  pretrig       = 15 * fsample; % i.e. 15 sec before trigger
  posttrig      = 15 * fsample; % i.e. 15 sec after trigger
  ntrls         = length(FOG_events);
  margin_FOG=6;
  for i = 1:ntrls
    % exclude FOGs that are preceded by another FOG within the 6 sec margins
    % (margin_FOG)
    if exclusion_FOG && ~isempty(FOG_events(find([FOG_events.end_time]<FOG_events(i).timestamp & [FOG_events.end_time]+margin_FOG>FOG_events(i).timestamp)))
      fprintf('close FOG was found. Excluding this FOG from the trials \n')
      excl = excl +1; 
      continue
    end
    % exclude FOGs that are preceded by a stop within the 5 sec margins
    % (margin_FOG)
    if exclusion_stop && ~isempty(stops(find([stops.end_time]<FOG_events(i).timestamp & [stops.end_time]+margin_FOG>FOG_events(i).timestamp)))
      fprintf('close stop was found. Excluding this FOG from the trials \n')
      excl = excl +1; 
      continue
    end
    % exclude short FOGs < 3sec
    if exclusion_short && FOG_events(i).duration<3*fsample
            fprintf('close stop was found. Excluding this FOG from the trials \n')
      excl = excl +1; 
      continue
    end
    offset    = -pretrig;  % number of samples prior to the trigger
    trlbegin  = onset_sample(i) - pretrig;
    trlend    = onset_sample(i) + posttrig;
    % FOG turn --> trialinfo = 1; FOG doorway --> trialinfo =2;
    % FOG start hesitation --> trialinfo =3; FOG others --> trialinfo =4
    if any(strcmp({'FOG_360_R', 'FOG_360_L', 'FOG_180_R', 'FOG_180_L'}, FOG_events(i).value))
      trig_info=1;
      tmp=strsplit(FOG_events(i).value, '_');
      onset_info=findtrigger(FOG_events(i), tmp{3}, events, FOG_events);
%       trig_info=findtrigger(FOG_events(i), 'turn', events, FOG_events);
    elseif strcmp('FOG_Doorway', FOG_events(i).value)
      trig_info=2;
      onset_info=findtrigger(FOG_events(i), 'narrow_passage', events, FOG_events);
%     elseif strcmp('FOG_SH', FOG_events(i).value)
%       trl_info=3;
%       trig_info=findtrigger(FOG_events(i), 'start_walking', events, FOG_events);
%     else
%       trl_info=4;
%       trig_info=nan;
    else 
      continue
    end
    % add FOG_info: 1 for FOG+ trials, 0 for FOG- trials
    FOG_info = 1;
    % add type_info: 1 for trembling, 2 for shuffling, 3 for akinesia
    type_info=findtype(events, onset_sample(i));
    % add DT_info: 0 for no DT, 1 for cogn. DT, 2 for motor DT, 3 for
    % cogn+motor DT.
    DT_info=findDT(Gait_tasks, onset_sample(i));
    newtrl    = [trlbegin trlend offset FOG_info trig_info onset_info type_info DT_info];
    trl       = [trl; newtrl]; % store in the trl matrix
  end
else
  trl=[];
end

%% define trials around the stop_walking trigger events
trigger_events=events(find(contains({events.type}, 'Gait_events')));
stops=events(find(contains({events.type}, 'Gait_events') & strcmp({events.value}, 'stop_walking')));
Gait_tasks=events(find(strcmp('Gait_task', {events.type})));
if ~isempty(stops)
  onset_sample = [stops.sample]; %! the end of the annotation is the real stop of the participant
  pretrig       = 15 * fsample; % i.e. 15 sec before trigger
  posttrig      = 15 * fsample; % i.e. 15 sec after trigger
  margin_trig        = 10;
  margin_FOG    = 6;
  for i=1:length(stops)
    % exclude stops that are preceded by a FOG within the 6 sec margins
    % (margin_FOG)
    if exclusion_FOG && exist('FOG_events') && ~isempty(FOG_events(find([FOG_events.end_time]<stops(i).timestamp & [FOG_events.end_time]+margin_FOG>stops(i).timestamp)))
      fprintf('close FOG was found. Excluding this stop_event from the trials \n')
      continue
    end
    % exclude stops that are preceded by another stop within the 6 sec margins
    % (margin_FOG)
    if exclusion_stop && ~isempty(stops(find([stops.end_time]<stops(i).timestamp & [stops.end_time]+margin_FOG>stops(i).timestamp)))
      fprintf('close stop was found. Excluding this stop_event from the trials \n')
      excl = excl +1; 
      continue
    end
    offset    = -pretrig;  % number of samples prior to the trigger
    trlbegin  = onset_sample(i) - pretrig;
    trlend    = onset_sample(i) + posttrig;
    gait_event=trigger_events(find(stops(i).timestamp>[trigger_events.timestamp]-margin_trig & stops(i).timestamp<[trigger_events.end_time]+margin_trig));
    % find the closest gait_event that is a turn or a narrow passage
    gait_event=gait_event(match_str({gait_event.value}, {'turn_360_R', 'turn_360_L', 'turn_180_R', 'turn_180_L', 'narrow_passage'}));
    [M, ix]=min(abs(stops(i).timestamp-[gait_event.timestamp]));
    gait_event=gait_event(ix);
    if any(ismember({gait_event.value},{'turn_360_R', 'turn_360_L', 'turn_180_R', 'turn_180_L'}))
      idx=find(ismember({gait_event.value},{'turn_360_R', 'turn_360_L', 'turn_180_R', 'turn_180_L'}),1);
      trig_info=1;
    elseif any(strcmp({gait_event.value}, 'narrow_passage'))
      idx=find(strcmp({gait_event.value}, 'narrow_passage'),1);
      trig_info=2;
    else 
      fprintf('no close trigger event was found for this stop event. \n')
      FOG_info=0;
      trig_info=nan;
      onset_info=nan;
      type_info=nan;
      DT_info=findDT(Gait_tasks, onset_sample(i));
      newtrl    = [trlbegin trlend offset FOG_info trig_info onset_info type_info DT_info];
      trl       = [trl; newtrl]; % store in the trl matrix
      continue
    end
    % check if during the trigger_event another start_walking or FOG was present
    strt=events(find(strcmp({events.value}, 'start_walking')));
    strt = strt(find([strt.timestamp]>gait_event(idx).timestamp & [strt.end_time]<stops(i).timestamp));
    try
      otherFOG=FOG_events(find([FOG_events.end_time]>gait_event(idx).timestamp & [FOG_events.end_time]<stops(i).timestamp));
    catch
      otherFOG=[];
    end
    if  ~isempty([strt; otherFOG])
      onset_info=max([[strt.timestamp] [otherFOG.end_time]])-stops(i).timestamp;
    else
      onset_info=gait_event(idx).timestamp-stops(i).timestamp;
    end
    FOG_info=0;
    type_info=nan;
    DT_info=findDT(Gait_tasks, onset_sample(i));
    newtrl    = [trlbegin trlend offset FOG_info trig_info onset_info type_info DT_info];
    trl       = [trl; newtrl]; % store in the trl matrix
  end
end

%% define trials around the normal gait events (FOG-)
if ~isempty(events) && any(strcmp('Gait_events', {events.type}))
  Gait_events=events(find(strcmp('Gait_events', {events.type})&contains({events.value}, {'turn', 'narrow_passage'})));
  FOG_events=events(find(strcmp('FOG_Trigger', {events.type})));
  Gait_tasks=events(find(strcmp('Gait_task', {events.type})));
  stops=events(find(strcmp({events.value}, 'stop_walking')));
%   stops=events(find(strcmp({events.value}, 'start_walking')));% if there was a stop walking, it starts again with a start walking
  strt=events(find(strcmp({events.value}, 'start_walking')));
  onset_sample  = [Gait_events.sample];
  pretrig       = 15 * fsample; % i.e. 15 sec before trigger
  posttrig      = 15 * fsample; % i.e. 15 sec after trigger
  ntrls         = length(Gait_events);
  margin_FOG=6;
  for i = 1:ntrls
    % check if during the trigger_event another start_walking was present
    strt_trig = strt(find([strt.timestamp]>Gait_events(i).timestamp & [strt.end_time]<Gait_events(i).end_time));
    if  ~isempty(strt_trig)
      Gait_events(i).timestamp=max([strt_trig.timestamp]);
      onset_sample(i)=max([strt_trig.sample]);
    end
    % exclude trials with close FOG events within a 6 seconds margin (so if
    % FOG before, during or after normal gait event trial)
    if ~isempty(find((Gait_events(i).end_time-([FOG_events.timestamp]-margin_FOG))>0 & (([FOG_events.end_time]+margin_FOG)-Gait_events(i).timestamp)>0));
      fprintf('close FOG was found. Excluding this normal gait event from the trials \n')
      continue
    end
    % exclude normal gait events that are preceded by a stop within the 6 sec margins
    % (margin_FOG)
    if exclusion_stop && ~isempty(stops(find([stops.end_time]<Gait_events(i).timestamp & [stops.end_time]+margin_FOG>Gait_events(i).timestamp)))
      fprintf('close stop was found. Excluding this trigger event from the trials \n')
      continue
    end
    FOG_info  = 2;
    onset_info = nan;
    offset    = -pretrig;  % number of samples prior to the trigger
    trlbegin  = onset_sample(i) - pretrig;
    trlend    = onset_sample(i) + posttrig;
    if contains(Gait_events(i).value, 'turn')
      trig_info=1;
    elseif contains(Gait_events(i).value, 'narrow_passage')
      trig_info=2;
    end
    type_info=nan;
    DT_info=findDT(Gait_tasks, onset_sample(i));
    newtrl    = [trlbegin trlend offset FOG_info trig_info onset_info type_info DT_info];
    trl       = [trl; newtrl]; % store in the trl matrix
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [onset_info] = findtrigger(FOG_event, triggerstring, events, FOG_events)
margin_trig=10;
trigger_event=events(find(contains({events.type}, 'Gait_events') & contains({events.value},triggerstring)));
trigger_event=trigger_event(find(FOG_event.timestamp>[trigger_event.timestamp]-margin_trig &  FOG_event.timestamp<[trigger_event.end_time]+margin_trig));
if isempty(trigger_event)
  timepoint=seconds(FOG_event.timestamp);
  timepoint.Format='hh:mm:ss';
  warning('no close trigger event was found for for %s at timepoint %s. Check timing and/or naming.', FOG_event.value, char(timepoint))
  onset_info=nan;
% elseif numel(trigger_event)>1
%   timepoint=seconds(FOG_event.timestamp);
%   timepoint.Format='hh:mm:ss';
%   warning('multiple possible trigger events were found for FOG event %s at timepoint %s.', FOG_event.value, char(timepoint));
%   display(struct2table(trigger_event))
%   trig_info=nan;
else
  % if multiple trigger_events are detected, chose the closest one
  if numel(trigger_event)>1
    [M, idx]=min(abs(FOG_event.timestamp-[trigger_event.timestamp]));
    trigger_event=trigger_event(idx);
  end    
  % check if during the trigger_event another start_walking or FOG was present
  strt=events(find(strcmp({events.value}, 'start_walking')));
  strt = strt(find([strt.timestamp]>trigger_event.timestamp & [strt.end_time]<FOG_event.timestamp));
  otherFOG=FOG_events(find([FOG_events.end_time]>trigger_event.timestamp & [FOG_events.end_time]<FOG_event.timestamp));
  if  ~isempty([strt; otherFOG]) & ~strcmp(triggerstring, 'start_walking')
    onset_info=max([[strt.timestamp] [otherFOG.end_time]])-FOG_event.timestamp;
  else
    onset_info=trigger_event.timestamp-FOG_event.timestamp;
  end
end

%%%%
function [type_info]=findtype(events, sampleonset)
    type=events(find(strcmp({events.type}, 'FOG_Type') & sampleonset==[events.sample])).value;
    switch type
      case 'Trembling'
        type_info=1;
      case 'Shuffling'
        type_info=2;
      case 'Akinesia'
        type_info=3;
      otherwise 
        type_info=nan;
    end

%%%%%
function [DT_info]=findDT(Gait_tasks, sampleonset)
    try
      task=Gait_tasks(find(sampleonset>[Gait_tasks.sample] & sampleonset<[Gait_tasks.sample]+[Gait_tasks.duration])).value;
    catch
        warning('stop event fell outside gait_task. Using previous gait_task to determine dual task condition');
        task=Gait_tasks(find(sampleonset>[Gait_tasks.sample],1, 'last')).value;
    end
    if contains(task, 'Dualmotorcog')
      DT_info=3;
    elseif contains(task, 'Dualmotor')
      DT_info=2;
    elseif contains(task, 'Dualcog')
      DT_info=1;
    else
      DT_info=0;
    end