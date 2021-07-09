function [condFOG, condStop, condTrig]=timelockCond(proc_dir, subjects, condition, variables, varargin)
%
% This function split the created condition trials FOG trials, stop trials
% and trigger trials performs a timelock analysis for the given condition and the given
% variables. It creates figures for each patient seperately and stores
% them.
%
% Use as
%   [condFOG, condStop, condTrig]    = timelockCond(proc_dir, subjects, condition, variables, varargin)
%
% INPUT:
%       proc_dir    = folder where all cond_trials are stored
%       subjects    = vector representing the subjects to analyse
%       condition   = the condition for which you would like to perform the
%       analysis. Options are 'all', 'turning', 'doorway', 'trembling',
%       'shuffling', 'akinesia', 'MT', 'cDT', and 'mDT'.
%       variables   = character array with the variables used for the
%       analysis
% Additional options can be specified in key-value pairs and can be:
%       'vis' = 1 or 0 for plotting the results of the timelock analysis
%       (default = 1)
%       'save_fig'   = 1 or 0 for saving the created figures (default = 1)
%       'baseline' = [begin end] to perform baseline correction after
%       timelock analysis (default = [-15 -10]);
%
% OUTPUT
%       [condFOG, condStop, condTrig]  = output data of the timelock analysis for the
%       FOG, stop, and trigger trials respectively 
%
% dependencies: plotCI

%% get the options
vis=ft_getopt(varargin, 'vis',1);
save_fig=ft_getopt(varargin, 'save_fig', 1);
baseline=ft_getopt(varargin, 'baseline', [-15 -10]);


% provide the function with the necessary information
switch condition
  case 'all'
    C=0; V=0;
  case 'turning'
    C=2; V=1;
    name='turning';
  case 'doorway'
    C=2; V=2;
    name='narrow passage';
  case 'trembling'
    C=4; V=1;
    name='trembling';
  case 'shuffling'
    C=4; V=2;
    name='shuffling';
  case 'akinesia'
    C=4; V=3;
    name='akinesia';
  case 'MT'
    C=5; V=0;
    name='mono-task';
  case 'cDT'
    C=5; V=1;
    name='cognitive dual-task';
  case 'mDT'
    C=5; V=2;
    name='motor dual-task';
end
% convert a single character to a character array
if ischar(variables)
  variables={variables};
end

%% Main part
for i=subjects
  %% timelock analysis
  % FOG
  id_folder=fullfile(proc_dir, sprintf('sub-PD%.2d', i));
  session=load(fullfile(id_folder, 'run.mat'));
  load(fullfile(id_folder, 'cond_trials.mat'));
  % combine trembling with shuffling
  warning('combining the trembling with the shuffling type')
  shuff=find(cond_trials.trialinfo(:,4)==2);
  cond_trials.trialinfo(shuff,4)=1;
  % timelock analysis
  cfg=[];
  if [C V]==[0 0]
    cfg.trials = find(cond_trials.trialinfo(:,1)==1);
    % exceptions for subject 1 & 2: FOG_course mcDT --> counts as motor and
    % cognitive DT
  elseif (i==1 | i==2) & C==5 & any(V==[1 2])
    cfg.trials = find(cond_trials.trialinfo(:,1)==1 & (cond_trials.trialinfo(:,C)==V|cond_trials.trialinfo(:,C)==3));
  else
    cfg.trials = find(cond_trials.trialinfo(:,1)==1 & cond_trials.trialinfo(:,C)==V);
  end
  if isempty(cfg.trials)
    condFOG{i}=[];
    condStop{i}=[];
    condTrig{i}=[];
    continue
  end
  timelock_condFOG=ft_timelockanalysis(cfg,cond_trials);
  cfg=[]; cfg.baseline=baseline; % baseline correction
  condFOG{i}=ft_timelockbaseline(cfg, timelock_condFOG);
  % FOG-
  cfg=[];
  if [C V]==[0 0] | any(strcmp(condition, {'trembling', 'shuffling', 'akinesia'}))
    cfg.trials = find(cond_trials.trialinfo(:,1)==0);
  elseif (i==1 | i==2) & C==5 & any(V==[1 2])
    cfg.trials = find(cond_trials.trialinfo(:,1)==0 & (cond_trials.trialinfo(:,C)==V|cond_trials.trialinfo(:,C)==3));
  else
    cfg.trials = find(cond_trials.trialinfo(:,1)==0 & cond_trials.trialinfo(:,C)==V);
  end
  timelock_condStop=ft_timelockanalysis(cfg,cond_trials);
  cfg=[]; cfg.baseline=baseline; % baseline correction 
  condStop{i}=ft_timelockbaseline(cfg, timelock_condStop);
  % normal event trial
  cfg=[];
  if [C V]==[0 0] | any(strcmp(condition, {'trembling', 'shuffling', 'akinesia'}))
    cfg.trials = find(cond_trials.trialinfo(:,1)==2);
  elseif (i==1 | i==2) & C==5 & any(V==[1 2])
    cfg.trials = find(cond_trials.trialinfo(:,1)==2 & (cond_trials.trialinfo(:,C)==V|cond_trials.trialinfo(:,C)==3));
  else
    cfg.trials = find(cond_trials.trialinfo(:,1)==2 & cond_trials.trialinfo(:,C)==V);
  end
  if isempty(cfg.trials)
    condTrig{i}=[];
  else
    timelock_condTrig=ft_timelockanalysis(cfg,cond_trials);
    cfg=[]; cfg.baseline=baseline; % baseline correction
    condTrig{i}=ft_timelockbaseline(cfg, timelock_condTrig);
  end
  
  %% plot with CI
  if vis
    for v=1:length(variables)
      figure;
      ylim([-7 7]);
      y_lim=ylim;
      ft_plot_box([-6 -3, y_lim], 'facecolor', [0.6 0.6 0.6], 'facealpha', 0.0)
      ft_plot_box([-3 0, y_lim], 'facecolor', [0.6 0.6 0.6], 'facealpha', 0.5)
      ft_plot_box([0, 3, y_lim], 'facecolor', [0.6 0.6 0.6], 'facealpha', 0.8)
      
      Nfog=length(timelock_condFOG.cfg.trials);
      Nstop=length(timelock_condStop.cfg.trials);
      if ~isempty(condTrig{i})
        Ntrig=length(timelock_condTrig.cfg.trials);
        c=plotCI(condTrig{i}, variables{v}, Ntrig, [0.20784  0.60784  0.45098], 'variance', timelock_condTrig.var);
      else
        Ntrig=0;
      end
      a=plotCI(condFOG{i}, variables{v},  Nfog, [0.83529  0.36863  0], 'variance', timelock_condFOG.var);
      b=plotCI(condStop{i}, variables{v}, Nstop, [0.13333  0.44314  0.69804], 'variance', timelock_condStop.var);
      
      if ~isempty(condTrig{i})
        legend([a,c,b],{'FOG', 'normal gait event', 'stop'});
      else 
        legend([a,b],{'FOG', 'stop'});
      end
      xticks([-15:3:15])
      ft_plot_text(-4.5, y_lim(2)-0.1*y_lim(2), 'baseline', 'fontsize',20);
      ft_plot_text(-1.5, y_lim(2)-0.1*y_lim(2), 'preFOG', 'fontsize',20);
      ft_plot_text(1.5, y_lim(2)-0.1*y_lim(2), 'FOG', 'fontsize',20);
      if C==0
        title(sprintf('average %s for PD-%s over %d FOG episodes, %d stop episodes and %d trigger trials', variables{v}, session.run(1).info.ID, Nfog, Nstop, Ntrig))
      else
        title(sprintf('average %s during %s for PD-%s over %d FOG episodes, %d stop episodes and %d trigger trials', variables{v}, name, session.run(1).info.ID, Nfog, Nstop, Ntrig))
      end
      if save_fig
        if C==0
          folder=fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_FOGvStopvTrig', variables{v}));
        elseif C==2
          folder=fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_FOGvStopvTrig', variables{v}), 'byTrigger');
        elseif C==4
          folder=fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_FOGvStopvTrig', variables{v}), 'byType');
        elseif C==5
          folder=fullfile('F:\Brainwave_exp2\figures\', sprintf('%s_FOGvStopvTrig', variables{v}), 'byDT');
        end
        if C==0
          file=sprintf('%s.jpg', session.run(1).info.ID);
        else
          file=sprintf('%s_%s.jpg', session.run(1).info.ID, condition);
        end
        if ~exist(folder)
          mkdir(folder);
        end
        saveas(gcf, fullfile(folder, file))
      end
    end
  end
end


