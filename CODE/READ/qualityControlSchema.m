function rows = qualityControlSchema()
% Supported advanced settings. One schema drives defaults, GUI and summaries.
% Columns: tab, dotted field, label, default, editor (or popup choices).
rows = {
'Doppler','OTHER.CS.D_robust','Robust Doppler integration',false,'bool';
'Doppler','OTHER.CS.D_mad_factor','MAD multiplier',6,'number';
'Doppler','OTHER.CS.D_freq_enable','Frequency slots enabled [1 2 3]',true(1,3),'matrix';
'Doppler','OTHER.CS.D_system_freq_enable','GPS/GLO/GAL/BDS/QZSS by frequency slot',true(5,3),'matrix';
'TDCP','OTHER.CS.TDCP_log_only','Record only (do not reset ambiguities)',false,'bool';
'TDCP','OTHER.CS.TDCP_z_factor','MAD multiplier',5,'number';
'TDCP','OTHER.CS.TDCP_min_sats','Minimum satellites',6,'number';
'TDCP','OTHER.CS.TDCP_max_reject','Maximum rejections per frequency',2,'number';
'Cold start','PROC.cold_start.enable','Enable segment cold start',false,'bool';
'Cold start','PROC.cold_start.window_epochs','Window (epochs)',10,'number';
'Cold start','PROC.cold_start.min_samples','Minimum samples',3,'number';
'Cold start','PROC.cold_start.robust_code','Robust code weights within window',false,'bool';
'Cold start','PROC.cold_start.huber_c','Huber multiplier',1.5,'number';
'Cold start','PROC.cold_start.scale_floor_m','Scale floor (m)',0.25,'number';
'Cold start','PROC.cold_start.weight_floor','Minimum weight',0.05,'number';
'Prediction','PROC.predicted_phase.enable','Use predicted-phase metadata',false,'bool';
'Prediction','PROC.predicted_phase.metadata_file','Prediction metadata CSV','','file';
'Prediction','PROC.predicted_phase.max_prediction_length','Maximum prediction length (epochs)',1,'number';
'Prediction','PROC.predicted_phase.sigma_scale','Metadata sigma multiplier',1,'number';
'Prediction','PROC.predicted_phase.sigma_floor_m','Sigma floor (m)',0.03,'number';
'Prediction','PROC.predicted_phase.time_tolerance_ms','Time matching tolerance (ms)',2,'number';
'Prediction','PROC.predicted_phase.exclude_from_cycle_slip','Exclude predicted phase from non-LLI detectors',true,'bool';
'Prediction quality','PROC.predicted_phase.quality_rms_file','Quality RMS CSV','','file';
'Prediction quality','PROC.predicted_phase.quality_max_rms_m','Maximum quality RMS (m)',0.5,'number';
'Prediction quality','PROC.predicted_phase.quality_sigma_scale','Quality sigma multiplier',1,'number';
'Prediction quality','PROC.predicted_phase.quality_min_samples','Minimum quality samples',10,'number';
'Prediction quality','PROC.predicted_phase.reject_if_quality_missing','Reject predictions without quality evidence',true,'bool';
'Prediction quality','PROC.predicted_phase.allowed_signals','Allowed signals (comma separated; empty=all)',{},'signals';
'RAIM','PROC.raim.enable','Enable code integrity monitor',false,'bool';
'RAIM','PROC.raim.test_model','Monitor test model','wls_residual',{'wls_residual','innovation'};
'RAIM','PROC.raim.pfa_global','Global false-alarm probability',1e-3,'number';
'RAIM','PROC.raim.min_redundancy','Minimum redundancy',1,'number';
'RAIM','PROC.raim.capture_stride','Replay capture interval (0=off)',0,'number';
'RAIM action','PROC.raim.experiment_action','Experimental action','none',{'none','exclude_code','downweight_code'};
'RAIM action','PROC.raim.calibration_file','Frozen calibration MAT','','file';
'RAIM action','PROC.raim.validation_gps_week','Action GPS week (required)',NaN,'number';
'RAIM action','PROC.raim.validation_start_sow','Action starts at GPS seconds of week',NaN,'number';
'RAIM action','PROC.raim.downweight_variance_factor','Code variance multiplier',25,'number';
'Diagnostics','EXP.quality_diagnostics','Save detailed frequency diagnostics in data4plot.mat',true,'bool';
};
end
