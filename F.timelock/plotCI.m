function h=plotCI(data_GA, channel, N, color, varargin)

% options:
var=ft_getopt(varargin, 'variance'); % this provides the option to manually add the variance matrix if not available in data_GA

chanidx=strcmp(data_GA.label, channel);

x=data_GA.time;
ymean=data_GA.avg(chanidx,:);
try
  ySEM=sqrt(data_GA.var(chanidx,:))/sqrt(N);
catch
  ySEM=sqrt(var(chanidx,:))/sqrt(N);
end

CI95=tinv([0.025 0.975], N-1);
yCI95=bsxfun(@times, ySEM, CI95(:));
ft_plot_vector(x, yCI95+ymean, 'highlight', ones(size(ymean)), 'highlightstyle', 'difference', 'color', color,'facecolor', color, 'facealpha', 0.5);
hold on;
h=ft_plot_vector(x, ymean, 'color', color, 'linewidth', 2);
