function run = Zscore_variables(run, varargin)
% function to show histograms of the variables over all the runs for each
% participant and calculate z-scores based on all the runs.

% get options
vis=ft_getopt(varargin, 'vis', 0);
% variables of interst
var=run(1).variables.label(~contains(run(1).variables.label, 'Z'));
n=length(var);

for v=1:length(var)
% collect data of all runs
variables_all=[];
chan_var=find(strcmp(run(1).variables.label, var{v}),1);
for j=1:length(run)
  variables_all=[variables_all run(j).variables.trial{1}(chan_var,:)];
end

% create histograms
if vis
switch var{v}
  case {'heartrate'}
    range=[50:1:200];
  otherwise 
    range=[-15:1:15];
end
figure; hist(variables_all, range); title(sprintf('%s for all runs together PD-%s', var{v}, run(1).info.ID));
if ~exist(fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_histograms', var{v})))
  mkdir(fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_histograms', var{v})));
end
saveas(gcf, fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_histograms', var{v}), sprintf('%s.jpg', run(1).info.ID)))
end

% calculate Z scores
mean_var= nanmean(variables_all); 
std_var= nanstd(variables_all);
for j=1:length(run)
  var_Z=(run(j).variables.trial{1}(chan_var,:)-mean_var)/std_var;
  run(j).variables.label(n+v,:)={sprintf('%s_Z', var{v})};
  run(j).variables.trial{1}(n+v,:)=var_Z;
end

end