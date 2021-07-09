function HC_grandaverageCond(condFOG, condStop, condTrig, subjects, condition, variables, varargin)
%
% This function calculates the grand average over all patients of the condFOG, condStop and condTrig data
% for the given condition and the given variables.
% It creates figures for each variable and stores them.
%
% Use as
%    HC_grandaverageCond(condFOG, condStop, condTrig, subjects, condition, variables, varargin)
%
% INPUT:
%       condFOG     = cell array of the timelock average for the FOG+ trials
%       of all patients generated by HC_timelock
%       condStop     = cell array of the timelock average for the stop trials
%       of all patients generated by HC_timelock
%       condTrig   = cell array of the timelock average for the trigger
%       trials of all patients generated by HC_timelockCond 
%       subjects    = vector representing the subjects to analyse
%       condition   = the condition for which you would like to perform the
%       analysis. Options are 'all', 'turning', 'doorway', 'trembling',
%       'shuffling', 'akinesia', 'MT', 'cDT', and 'mDT'.
%       variables   = character array with the variables used for the
%       analysis. If z-scores are available for the variable, it
%       automatically uses the z-scores instead of the absolute values
% Additional options can be specified in key-value pairs and can be:
%       'vis' = 1 or 0 for plotting the results of the grand average analysis
%       (default = 1)
%       'save_fig'   = 1 or 0 for saving the created figures (default = 1)
%
%
% dependencies: HC_plotCI

%% get options
vis=ft_getopt(varargin, 'vis', 1);
save_fig=ft_getopt(varargin, 'save_fig', 1);

% provide the function with the necessary information
switch condition
  case 'turning'
    name='turning';
  case 'doorway'
    name='narrow passage';
  case 'trembling'
    name='trembling';
  case 'shuffling'
    name='shuffling';
  case 'akinesia'
    name='akinesia';
  case 'MT'
    name='mono-task';
  case 'cDT'
    name='cognitive dual-task';
  case 'mDT'
    name='motor dual-task';
  case 'mcDT'
    name='motor-cognitive dual-task';
end

% convert a single character to a character array
if ischar(variables)
  variables={variables};
end

% remove empty subjects
emptysubj=find(cellfun(@isempty,condFOG) | cellfun(@isempty, condTrig));
subjects=subjects(~ismember(subjects,emptysubj));

%% timelock grand average
cfg=[];
condFOG_GA=ft_timelockgrandaverage(cfg,condFOG{subjects});
condStop_GA=ft_timelockgrandaverage(cfg, condStop{subjects});
condTrig_GA=ft_timelockgrandaverage(cfg, condTrig{subjects});

%% plot with confidence intervals
% remark: CI for comparison between 2 conditions is smaller than for 1
% condition
if vis
  for v=1:length(variables)
    % use z-scores if available
    switch variables{v}
      case 'heartrate'
        warning('Using z-score of heartrate instead of heartrate')
        var='heartrate_Z';
      case 'heartperiod'
        warning('Using z-score of heartrate instead of heartrate')
        var='heartperiod_Z';
      otherwise
        var=variables{v};
    end
    % plot
    figure;
    if contains(var, 'Z')
      ylim([-1 1]);
    elseif contains(var, 'mFI')
      ylim([0 10]);
    elseif contains(var, 'FI')
      ylim([0 10]);
    elseif contains(var, 'change')
      ylim([-1.5 1])
    end
    y_lim=ylim;
    ft_plot_box([-6 -3, ylim], 'facecolor', [0.6 0.6 0.6], 'facealpha', 0.0)
    ft_plot_box([-3 0, ylim], 'facecolor', [0.6 0.6 0.6], 'facealpha', 0.5)
    ft_plot_box([0, 3, ylim], 'facecolor', [0.6 0.6 0.6], 'facealpha', 0.8)
    c=plotCI(condTrig_GA, var, length(subjects), [0.20784  0.60784  0.45098]);   
    b=plotCI(condStop_GA, var, length(subjects), [0.13333  0.44314  0.69804]); 
    a=plotCI(condFOG_GA, var, length(subjects), [0.83529  0.36863  0]); 


    ft_plot_text(-4.5, y_lim(2)-0.1*y_lim(2), 'baseline', 'fontsize',20);
    ft_plot_text(-1.5, y_lim(2)-0.1*y_lim(2), 'preFOG', 'fontsize',20);
    ft_plot_text(1.5, y_lim(2)-0.1*y_lim(2), 'FOG', 'fontsize',20);
    switch condition
      case 'all'
        title(sprintf('grand average %s over %d patients', var, length(subjects)))
      otherwise
        title(sprintf('grand average %s during %s over %d patients', var, name,length(subjects)))
    end
    legend([a, c, b], {'FOG','normal gait event', 'stop'});
    xticks([-15:3:15])
    xlabel('time (s)'); ylabel(var, 'Rotation', 90);
    set(gca, 'Fontsize', 25);
     if save_fig
       switch condition
         case 'all'
           folder=fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_FOGvStopvTrig', variables{v}));
         case {'turning', 'doorway'}
           folder=fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_FOGvStopvTrig', variables{v}), 'byTrigger');
         case {'trembling', 'shuffling', 'akinesia'}
           folder=fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_FOGvStopvTrig', variables{v}), 'byType');
         case {'MT', 'cDT', 'mDT', 'mcDT'}
           folder=fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_FOGvStopvTrig', variables{v}), 'byDT');
       end
      switch condition
        case 'all'
          file='GrandAverage.jpg';
        otherwise
          file=sprintf('GrandAverage_%s.jpg', condition);
      end
      if ~exist(folder)
        mkdir(folder);
      end
      saveas(gcf, fullfile(folder, file))
    end
  end
end