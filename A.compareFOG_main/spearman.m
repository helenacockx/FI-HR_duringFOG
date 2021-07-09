function [correlation] = spearman(sub)
% Performs: calculate correlation coefficient between FOG raters
% Input:
% - sub: structure with FOG events for each subject
% Output:
% - correlation: table with rho and p-value from Spearman rank correlation for nrFOG and durFOG
% Dependencies: swtest

%% Get nrFOG and durFOG per rater
raters = {sub(1).rater.name};
[nrFOG, durFOG] = deal(array2table(zeros(length(sub), length(raters)), 'VariableNames', raters, 'RowNames', {sub.ID}));

for i = 1:length(sub)
  nrFOG{sub(i).ID,1}=height(sub(i).FOG_events.rater1);
  durFOG{sub(i).ID,1}=sum(sub(i).FOG_events.rater1.duration);
    nrFOG{sub(i).ID,2}=height(sub(i).FOG_events.rater2);
  durFOG{sub(i).ID,2}=sum(sub(i).FOG_events.rater2.duration);
end % for i

%% Create scatterplot
% Number of FOG
F1 = figure;
F1.Name = 'nrFOG_correlation raters';
scatter(nrFOG{:,raters{1}}, nrFOG{:,raters{2}}, 'filled');
title('total number of FOG per ID'); xlabel(raters{1}), ylabel(raters{2});
grid on; axis square; xlim([0 100]); ylim([0 100])

% Duration of FOG
F2 = figure;
F2.Name = 'durFOG_correlation raters';
scatter(durFOG{:,raters{1}}, durFOG{:,raters{2}}, 'filled');
title('total duration of FOG per ID (sec)'); xlabel(raters{1}), ylabel(raters{2});
grid on; axis square; xlim([0 1200]); ylim([0 1200])


%% Test for normality of data (assumption of bivariate normality)
% normality = array2table(zeros(2,2), 'VariableNames', raters, 'RowNames', {'nrFOG', 'durFOG'});
% [H.nrFOG, normality{'nrFOG',:}, ~] = arrayfun(@(x) swtest(nrFOG{:,(x)}, 0.05), [1 2]);
% [H.durFOG, normality{'durFOG',:}, ~] = arrayfun(@(x) swtest(durFOG{:,(x)}, 0.05), [1 2]);

% no normal distribution --> using Spearman's correlation 

%% Calculate Spearman's correlation
correlation = array2table(zeros(2,2), 'VariableNames', {'rho', 'pValue'}, 'RowNames', {'nrFOG', 'durFOG'});
[correlation{'nrFOG', 'rho'}, correlation{'nrFOG', 'pValue'}] = corr(nrFOG{:,1}, nrFOG{:,2}, 'Type', 'Spearman');
[correlation{'durFOG', 'rho'}, correlation{'durFOG', 'pValue'}] = corr(durFOG{:,1}, durFOG{:,2}, 'Type', 'Spearman');

end % function