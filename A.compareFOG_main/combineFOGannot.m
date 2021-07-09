function [FOG_events, info]=combineFOGannot(FOG_events)
% function to compare the FOG annotations of both raters and define whether
% they agreed upon the annotations or not. The column 'agreement' (1 if agreed annotation, 0 if not agreed
% annotation) shows whether the annotations overlapped. If the annotations
% did not overlap, the column 'rater' shows which rater annotated the
% event. The columns 'check_trigger' and 'check_type' is 1 if the
% annotations overlapped, but the raters did not agree on the trigger or type of FOG.

%% initialization
tolerance = 2;   % seconds that FOG episodes counted by WS/AA may not overlap but are still counted as 1
info.diff_begin=[]; % seconds that the begin_time of the annotation differed between the first and the second annotator if an annotation was combined.
info.diff_end=[]; % seconds that the end_time of the annotation differed between the first and the second annotator if an annotation was combined.
info.diff_middle=[]; % if the annotation of one of the raters falls within the of the other, seconds that the end_time of the annotation differed between the first and the second annotator if an annotation was combined.

%%
if isempty(FOG_events)
  return
end
FOG_events.combined=table('Size', [0, 13],...
  'VariableNames', {'FOG_Trigger', 'FOG_Type', 'begin_time', 'end_time', 'duration', 'session_number', 'file', 'NOTES_rater1', 'NOTES_rater2', 'check_trigger', 'check_type', 'agreement', 'rater'},...
  'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double', 'string','string','string', 'double', 'double', 'double', 'double'});

% loop over sessions
for i=1:max(FOG_events.rater1.session_number(end), FOG_events.rater2.session_number(end))
  fprintf('.......... %s .......... \n', char(unique(FOG_events.rater1.file(find(FOG_events.rater1.session_number==i)))));
  % select FOG_events of this session
  session_events.rater1=FOG_events.rater1(find(FOG_events.rater1.session_number==i),:);
  session_events.rater2=FOG_events.rater2(find(FOG_events.rater2.session_number==i),:);
  
  % loop over FOG_events with different indexing for rater 1 (j) and rater
  % 2 (k)
  j=1; k=1;
  while j<=height(session_events.rater1) & k<=height(session_events.rater2)
    % get the maximum value of the begin time of the current FOG_events of
    % the two raters
    begin_tmp=max(session_events.rater1.begin_time(j),session_events.rater2.begin_time(k));
    % get the minimum value of the end time of the current FOG_events of
    % the two raters
    end_tmp=min(session_events.rater1.end_time(j), session_events.rater2.end_time(k));
    % if the end_tmp > begin_tmp, the FOG_events of the two raters occured
    % in each other range.
    if end_tmp>begin_tmp
      % create a combined FOG_event by using the outer borders of the
      % FOG_event
      begin_time=min(session_events.rater1.begin_time(j),session_events.rater2.begin_time(k));
      end_time=max(session_events.rater1.end_time(j), session_events.rater2.end_time(k));
      duration=end_time-begin_time;
      % calculate the differences in timing between the two annotators
      info.diff_begin=[info.diff_begin abs(session_events.rater1.begin_time(j)-session_events.rater2.begin_time(k))];
      info.diff_end=[info.diff_end abs(session_events.rater1.end_time(j)-session_events.rater2.end_time(k))];
      
      % check if the annotations of the FOG_Trigger and the FOG_Type are
      % the same
      if strcmp(session_events.rater1.FOG_Trigger(j), session_events.rater2.FOG_Trigger(k))
        FOG_Trigger=char(session_events.rater1.FOG_Trigger(j));
        check_trigger=0;
      else
        FOG_Trigger=[char(session_events.rater1.FOG_Trigger(j)) '/' char(session_events.rater2.FOG_Trigger(k))];
        check_trigger=1;
      end
      if strcmp(session_events.rater1.FOG_Type(j), session_events.rater2.FOG_Type(k))
        FOG_Type=char(session_events.rater1.FOG_Type(j));
        check_type=0;
      else
        FOG_Type=[char(session_events.rater1.FOG_Type(j)) '/' char(session_events.rater2.FOG_Type(k))];
        check_type=1;
      end
      % add the other info
      session_number=i;
      file=char(session_events.rater1.file(j));
      try
        NOTES_rater1=char(session_events.rater1.NOTES(j));
      catch
        NOTES_rater1='';
      end
      try
        NOTES_rater2=char(session_events.rater2.NOTES(k));
      catch
        NOTES_rater2='';
      end
      % this is an agreed FOG_event
      agreement=1;
      rater=0;
      % store in FOG_events.combined
      FOG_events.combined(end+1,:)={FOG_Trigger, FOG_Type, begin_time, end_time, duration, session_number, file, NOTES_rater1, NOTES_rater2, check_trigger, check_type, agreement, rater};
      % update indexes
      j=j+1; k=k+1;
      
    % if the begin_time of one the FOG_events falls within the last
    % FOG_event of that session, combine this FOG_event with the previous one
    elseif ~(j==1 & k==1) && ~isempty(FOG_events.combined) && min(session_events.rater1.begin_time(j), session_events.rater2.begin_time(k))<FOG_events.combined.end_time(end)
      % define which rater entails this event
      [x, r] =min([session_events.rater1.begin_time(j), session_events.rater2.begin_time(k)]);
      if r==1
        %  if this event only entails notes, only add notes
        if strcmp(session_events.rater1.FOG_Trigger(j), 'NOTES')
          FOG_events.combined.NOTES_rater1(end)= [char(FOG_events.combined.NOTES_rater1(end)) ' // ' char(session_events.rater1.NOTES(j))];
          j=j+1;
          continue
        end
        % calculate the differences in timing between the two annotators
        info.diff_middle=[info.diff_middle abs(session_events.rater1.begin_time(j)-session_events.rater1.end_time(j-1))];
        info.diff_end(end)=abs(FOG_events.combined.end_time(end)-session_events.rater1.end_time(j));
        % update timing if necessary
        if session_events.rater1.end_time(j)>FOG_events.combined.end_time(end)
          FOG_events.combined.end_time(end)=session_events.rater1.end_time(j);
          FOG_events.combined.duration(end)=FOG_events.combined.end_time(end)-FOG_events.combined.begin_time(end);
        end
        % check if the annotations of the FOG_Trigger and the FOG_Type are
        % the same
        if ~contains(FOG_events.combined.FOG_Trigger(end), session_events.rater1.FOG_Trigger(j))
          FOG_events.combined.FOG_Trigger(end)=[char(FOG_events.combined.FOG_Trigger(end)) '/' char(session_events.rater1.FOG_Trigger(j))];
          FOG_events.combined.check_trigger(end)=1;
        end
        if ~contains(FOG_events.combined.FOG_Type(end), session_events.rater1.FOG_Type(j))
          FOG_events.combined.FOG_Type(end)=[char(FOG_events.combined.FOG_Type(end)) '/' char(session_events.rater1.FOG_Type(j))];
          FOG_events.combined.check_type(end)=1;
        end
        % add notes if present
        try
          FOG_events.combined.NOTES_rater1(end)= [char(FOG_events.combined.NOTES_rater1(end)) ' // ' char(session_events.rater1.NOTES(j))];
        end
        % update index
        j=j+1;
      elseif r==2
        %  if this event only entails notes, only add notes
        if strcmp(session_events.rater2.FOG_Trigger(k), 'NOTES')
          FOG_events.combined.NOTES_rater2(end)= [char(FOG_events.combined.NOTES_rater2(end)) ' // ' char(session_events.rater2.NOTES(k))];
          k=k+1;
          continue
        end
        % calculate the differences in timing between the two annotators
        info.diff_middle=[info.diff_middle abs(session_events.rater2.begin_time(k)-session_events.rater2.end_time(k-1))];
        info.diff_end(end)=abs(FOG_events.combined.end_time(end)-session_events.rater2.end_time(k));
        % update timing if necessary
        if session_events.rater2.end_time(k)>FOG_events.combined.end_time(end)
          FOG_events.combined.end_time(end)=session_events.rater2.end_time(k);
          FOG_events.combined.duration(end)=FOG_events.combined.end_time(end)-FOG_events.combined.begin_time(end);
        end
        % check if the annotations of the FOG_Trigger and the FOG_Type are
        % the same
        if ~contains(FOG_events.combined.FOG_Trigger(end), session_events.rater2.FOG_Trigger(k))
          FOG_events.combined.FOG_Trigger(end)=[char(FOG_events.combined.FOG_Trigger(end)) '/' char(session_events.rater2.FOG_Trigger(k))];
          FOG_events.combined.check_trigger(end)=1;
        end
        if ~contains(FOG_events.combined.FOG_Type(end), session_events.rater2.FOG_Type(k))
          FOG_events.combined.FOG_Type(end)=[char(FOG_events.combined.FOG_Type(end)) '/' char(session_events.rater2.FOG_Type(k))];
          FOG_events.combined.check_type(end)=1;
        end
        % add notes if present
        try
          FOG_events.combined.NOTES_rater2(end)= [char(FOG_events.combined.NOTES_rater2(end)) ' // ' char(session_events.rater2.NOTES(k))];
        end
        % update index
        k=k+1;
      end        
 
    % else find the next FOG_event and store this in the
    % FOG_events.combined.
    else
      % define which rater entails the next FOG event
      [begin_time, r] =min([session_events.rater1.begin_time(j), session_events.rater2.begin_time(k)]);
      if r==1
        % skip if this event only entails notes
        if strcmp(session_events.rater1.FOG_Trigger(j), 'NOTES')
          j=j+1;
          continue
        end
        end_time=session_events.rater1.end_time(j);
        duration=end_time-begin_time;
        FOG_Trigger=char(session_events.rater1.FOG_Trigger(j));
        check_trigger=0;
        FOG_Type=char(session_events.rater1.FOG_Type(j));
        check_type=0;
        session_number=i;
        file=char(session_events.rater1.file(j));
        try
          NOTES_rater1=char(session_events.rater1.NOTES(j));
          NOTES_rater2='';
        catch
          NOTES_rater1='';
          NOTES_rater2='';
        end
        % this is not an agreed FOG
        agreement=0;
        rater=r;
        % update index
        j=j+1;
      elseif r==2
        % skip if this event only entails notes
        if strcmp(session_events.rater2.FOG_Trigger(k), 'NOTES')
          k=k+1;
          continue
        end
        end_time=session_events.rater2.end_time(k);
        duration=end_time-begin_time;
        FOG_Trigger=char(session_events.rater2.FOG_Trigger(k));
        check_trigger=0;
        FOG_Type=char(session_events.rater2.FOG_Type(k));
        check_type=0;
        session_number=i;
        file=char(session_events.rater2.file(k));
        try
          NOTES_rater1=char(session_events.rater2.NOTES(k));
          NOTES_rater2='';
        catch
          NOTES_rater1='';
          NOTES_rater2='';
        end
        % this is not an agreed FOG
        agreement=0;
        rater=r;
        % update index
        k=k+1;
      end
      % store in FOG_events.combined
      FOG_events.combined(end+1,:)={FOG_Trigger, FOG_Type, begin_time, end_time, duration, session_number, file, NOTES_rater1, NOTES_rater2, check_trigger, check_type, agreement, rater};
    end
  end
  
  % check if a FOG event is left for one of the two raters
  while j<=height(session_events.rater1)
    % if the begin_time of the FOG_events falls within the last
    % FOG_event of that session, combine this FOG_event with the previous one
    if ~(j==1 & k==1) && ~isempty(FOG_events.combined) && session_events.rater1.begin_time(j)<FOG_events.combined.end_time(end)
      %  if this event only entails notes, only add notes
      if strcmp(session_events.rater1.FOG_Trigger(j), 'NOTES')
        FOG_events.combined.NOTES_rater1(end)= [char(FOG_events.combined.NOTES_rater1(end)) ' // ' char(session_events.rater1.NOTES(j))];
        j=j+1;
        continue
      end
      % calculate the differences in timing between the two annotators
      info.diff_middle=[info.diff_middle abs(session_events.rater1.begin_time(j)-session_events.rater1.end_time(j-1))];
      info.diff_end(end)=abs(FOG_events.combined.end_time(end)-session_events.rater1.end_time(j));
      % update timing if necessary
        if session_events.rater1.end_time(j)>FOG_events.combined.end_time(end)
          FOG_events.combined.end_time(end)=session_events.rater1.end_time(j);
          FOG_events.combined.duration(end)=FOG_events.combined.end_time(end)-FOG_events.combined.begin_time(end);
        end
        % check if the annotations of the FOG_Trigger and the FOG_Type are
        % the same
        if ~contains(FOG_events.combined.FOG_Trigger(end), session_events.rater1.FOG_Trigger(j))
          FOG_events.combined.FOG_Trigger(end)=[char(FOG_events.combined.FOG_Trigger(end)) '/' char(session_events.rater1.FOG_Trigger(j))];
          FOG_events.combined.check_trigger(end)=1;
        end
        if ~contains(FOG_events.combined.FOG_Type(end), session_events.rater1.FOG_Type(j))
          FOG_events.combined.FOG_Type(end)=[char(FOG_events.combined.FOG_Type(end)) '/' char(session_events.rater1.FOG_Type(j))];
          FOG_events.combined.check_type(end)=1;
        end
        % add notes if present
        try
          FOG_events.combined.NOTES_rater1(end)= [char(FOG_events.combined.NOTES_rater1(end)) ' // ' char(session_events.rater1.NOTES(j))];
        end
        % update index
        j=j+1;
    % else find the next FOG_event and store this in the
    % FOG_events.combined.
    else
      % skip if this event only entails notes
      if strcmp(session_events.rater1.FOG_Trigger(j), 'NOTES')
        j=j+1;
        continue
      end
      begin_time=session_events.rater1.begin_time(j);
      end_time=session_events.rater1.end_time(j);
      duration=end_time-begin_time;
      FOG_Trigger=char(session_events.rater1.FOG_Trigger(j));
      check_trigger=0;
      FOG_Type=char(session_events.rater1.FOG_Type(j));
      check_type=0;
      session_number=i;
      file=char(session_events.rater1.file(j));
      try
        NOTES_rater1=char(session_events.rater1.NOTES(j));
        NOTES_rater2='';
      catch
        NOTES_rater1='';
        NOTES_rater2='';
      end
      % this is not an agreed FOG
      agreement=0;
      rater=1;
      % update index
      j=j+1;
      % store in FOG_events.combined
      FOG_events.combined(end+1,:)={FOG_Trigger, FOG_Type, begin_time, end_time, duration, session_number, file, NOTES_rater1, NOTES_rater2, check_trigger, check_type, agreement, rater};

    end
  end
      
  while k<=height(session_events.rater2)
    % if the begin_time of the FOG_events falls within the last
    % FOG_event of that session, combine this FOG_event with the previous one
    if ~(j==1 & k==1) && ~isempty(FOG_events.combined) && session_events.rater2.begin_time(k)<FOG_events.combined.end_time(end)
      %  if this event only entails notes, only add notes
      if strcmp(session_events.rater2.FOG_Trigger(k), 'NOTES')
        FOG_events.combined.NOTES_rater2(end)= [char(FOG_events.combined.NOTES_rater2(end)) ' // ' char(session_events.rater2.NOTES(k))];
        k=k+1;
        continue
      end
      % calculate the differences in timing between the two annotators
      info.diff_middle=[info.diff_middle abs(session_events.rater2.begin_time(k)-session_events.rater2.end_time(k-1))];
      info.diff_end(end)=abs(FOG_events.combined.end_time(end)-session_events.rater2.end_time(k));
      % update timing if necessary
      if session_events.rater2.end_time(k)>FOG_events.combined.end_time(end)
        FOG_events.combined.end_time(end)=session_events.rater2.end_time(k);
        FOG_events.combined.duration(end)=FOG_events.combined.end_time(end)-FOG_events.combined.begin_time(end);
      end
      % check if the annotations of the FOG_Trigger and the FOG_Type are
      % the same
      if ~contains(FOG_events.combined.FOG_Trigger(end), session_events.rater2.FOG_Trigger(k))
        FOG_events.combined.FOG_Trigger(end)=[char(FOG_events.combined.FOG_Trigger(end)) '/' char(session_events.rater2.FOG_Trigger(k))];
        FOG_events.combined.check_trigger(end)=1;
      end
      if ~contains(FOG_events.combined.FOG_Type(end), session_events.rater2.FOG_Type(k))
        FOG_events.combined.FOG_Type(end)=[char(FOG_events.combined.FOG_Type(end)) '/' char(session_events.rater2.FOG_Type(k))];
        FOG_events.combined.check_type(end)=1;
      end
      % add notes if present
      try
        FOG_events.combined.NOTES_rater2(end)= [char(FOG_events.combined.NOTES_rater2(end)) ' // ' char(session_events.rater2.NOTES(k))];
      end
      % update index
      k=k+1;
      % else find the next FOG_event and store this in the
      % FOG_events.combined.
    else
      % skip if this event only entails notes
      if strcmp(session_events.rater2.FOG_Trigger(k), 'NOTES')
        k=k+1;
        continue
      end
      begin_time=session_events.rater2.begin_time(k);
      end_time=session_events.rater2.end_time(k);
      duration=end_time-begin_time;
      FOG_Trigger=char(session_events.rater2.FOG_Trigger(k));
      check_trigger=0;
      FOG_Type=char(session_events.rater2.FOG_Type(k));
      check_type=0;
      session_number=i;
      file=char(session_events.rater2.file(k));
      try
        NOTES_rater1='';
        NOTES_rater2=char(session_events.rater2.NOTES(k));
      catch
        NOTES_rater1='';
        NOTES_rater2='';
      end
      % this is not an agreed FOG
      agreement=0;
      rater=2;
      % update index
      k=k+1;
      % store in FOG_events.combined
      FOG_events.combined(end+1,:)={FOG_Trigger, FOG_Type, begin_time, end_time, duration, session_number, file, NOTES_rater1, NOTES_rater2, check_trigger, check_type, agreement, rater};
    end
  end
    
end

%% NOTE: 
% better to handle this script differently next time:
% 1. make vectors (length of each session with a resolution of 0.1
% seconds) for each annotator with a 1 for FOG and a 0 for noFOG.
% 2. combine vectors by combi = rater1 + 2*rater2. Interpretation of this
% vector. 0=agreed noFOG; 3=agreed FOG; 1=FOG by rater1; 2 = FOG by rater2.
% 3. make new vector with 1 for all agreed FOG (3). if length(1/2)< tolerance (e.g. 2sec) and is followed/preceeded by 3--> make also one.
% 4. combine values of the annotations 1/2/3 (FOG_trigger, FOG_type)

% Besides, difficult to check annotations without backcorrection
