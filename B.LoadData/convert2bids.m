function convert2bids(data_raw, events, sub, run)

cfg=[];
cfg.method = 'convert';
cfg.bidsroot = 'F:\Brainwave_exp2\rawdata';
cfg.sub=sprintf('%02d', sub);
cfg.run=run;
cfg.task='gait';
cfg.datatype='physio';
cfg.events=events;
cfg.writejson = 'no'; % only write json at top level

cfg.dataset_description.writesidecar        = 'yes';
cfg.dataset_description.Name                = 'Brainwave FOG project 2';
cfg.dataset_description.Authors             = 'Y. Wang, H.M. Cockx, R.J.A. van Wezel';
cfg.dataset_description.Funding             = 'the Netherlands Organization for Scientific Research (NWO) (BrainWave project, 14714)';
cfg.dataset_description.EthicsApprovals     = 'medical ethics committee Arnhem-Nijmegen (NL60942.091.17)';

data2bids(cfg, data_raw);


