function kappa=kappacoeficientall(sub)

total_duration=0;
a=0; b=0; c=0; 
% loop over subjects
for i=1:length(sub)
  total_duration=total_duration+sum([sub(i).rater(1).sessions.duration]);
  
  idx_a=find(sub(i).FOG_events.combined.agreement==1);
  a=a+sum(sub(i).FOG_events.combined.duration(idx_a));
  
  idx_c=find(sub(i).FOG_events.combined.rater==1);
  c=c+sum(sub(i).FOG_events.combined.duration(idx_c));
  
  idx_b=find(sub(i).FOG_events.combined.rater==2);
  b=b+sum(sub(i).FOG_events.combined.duration(idx_b));
end

d=total_duration-a-b-c;

Po=(a+d)/total_duration;
Pyes=((a+c)/total_duration)*((a+b)/total_duration);
Pno=((b+d)/total_duration)*((c+d)/total_duration);

kappa=(Po-(Pyes+Pno))/(1-(Pyes+Pno));