function kappa=kappacoeficient(FOG_events, rater)

total_duration=sum([rater(1).sessions.duration]);

idx_a=find(FOG_events.combined.agreement==1);
a=sum(FOG_events.combined.duration(idx_a));

idx_c=find(FOG_events.combined.rater==1);
c=sum(FOG_events.combined.duration(idx_c));

idx_b=find(FOG_events.combined.rater==2);
b=sum(FOG_events.combined.duration(idx_b));

d=total_duration-a-b-c;

Po=(a+d)/total_duration;
Pyes=((a+c)/total_duration)*((a+b)/total_duration);
Pno=((b+d)/total_duration)*((c+d)/total_duration);

kappa=(Po-(Pyes+Pno))/(1-(Pyes+Pno));