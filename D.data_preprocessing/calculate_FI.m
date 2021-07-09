function [FI, freezeband, motorband, TPower]=calculate_FI(data, channel)
% parameters
total_length=length(data.time{1});
fs=data.fsample;
window_size=3*fs; % 3 seconds
han_win=hann(window_size)'; % hanning window

% select data
cfg=[];
cfg.channel=channel;
data=ft_selectdata(cfg, data);

% create empty variables
FI=nan(1,total_length);
freezeband=nan(1,total_length);
motorband=nan(1,total_length);
TPower=nan(1,total_length);

  %% loop over time windows
  for i=1:total_length
    if i<=window_size/2 | i>total_length-window_size/2+1 % skip if no full window can be created
      continue
    else
    data_win=data.trial{1}(i-window_size/2:i+window_size/2-1); % create time window
    data_han=data_win.*han_win; % apply hanning taper
    pow_spctr=fft(data_han); % calculate fast fourier transform
    power=abs(pow_spctr).^2/window_size; % calculate power (see: https://nl.mathworks.com/help/matlab/math/basic-spectral-analysis.html)
    f=(0:window_size-1)*(fs/window_size); % frequency range
    
    % auc of freezing and motor band
    foi_freezing=find(f>3 & f<=8);% frequencies of interest freezing band = 3-8 Hz
    foi_motor=find(f>=0.5 & f<=3); % frequencies of interest motor band = 0.5-3 Hz
    auc_freezing=trapz(power(foi_freezing)); % auc
    auc_motor = trapz(power(foi_motor)); % auc
    auc_total= trapz(power([foi_motor, foi_freezing]));
    
    %calculate the freezing index
    FI_chl = auc_freezing.^2/auc_motor.^2; % squared auc freezing band/squared auc motor band
    FI_norm=log(FI_chl*100); % normalize (see Moore et al, 2008)
    
    % store variables
    FI(1,i)=FI_norm; 
    freezeband(1,i)=log(auc_freezing*100);
    motorband(1,i)=log(auc_motor*100);
    TPower(1,i)=log(auc_total*100);
    end
  end

    
    