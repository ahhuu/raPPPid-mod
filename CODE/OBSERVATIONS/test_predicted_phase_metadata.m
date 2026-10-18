function test_predicted_phase_metadata()
% Focused mapping/default regression for metadata-aware predicted phase.

settings.PROC = struct();
settings = applyPredictedPhaseDefaults(settings);
assert(~settings.PROC.predicted_phase.enable);
settings.PROC.predicted_phase.enable = true;
metadata_file=[tempname '.csv'];
cleanup=onCleanup(@() delete(metadata_file)); %#ok<NASGU>
fid=fopen(metadata_file,'w');
fprintf(fid,'time,sat_id,freq,prediction_length,sigma_m,accepted,source,status\n');
fprintf(fid,'2026-04-26T02:40:49.999999,G01,L1C,1,0.1,true,doppler_forward,accepted\n');
fclose(fid);
settings.PROC.predicted_phase.metadata_file=metadata_file;
settings.PROC.predicted_phase.max_prediction_length = 1;
settings.INPUT.proc_freqs = 1;

emptySignals = struct('L1','','L2','','L3','');
obs.GPS = emptySignals; obs.GLO = emptySignals; obs.GAL = emptySignals;
obs.BDS = emptySignals; obs.QZSS = emptySignals;
obs.GPS.L1 = 'L1C';
metadata = loadPredictedPhaseMetadata(settings, obs);
assert(metadata.enabled && metadata.selected_records > 0);

dt = datetime('2026-04-26T02:40:49.999999', ...
    'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSSSS');
delta = dt-datetime(1980,1,6,0,0,0);
week = floor(days(delta)/7);
sow = seconds(delta-days(week*7));
Epoch = struct('sats',1,'gps_week',week,'gps_time',sow);
obs.use_column = cell(5,12); obs.use_column{1,1} = 1;
Epoch.obs = 1; Epoch.L1 = 1;
Epoch = attachPredictedPhaseMetadata(Epoch, metadata, settings, obs);
assert(Epoch.phase_predicted(1,1));
assert(Epoch.phase_prediction_length(1,1) == 1);
assert(abs(Epoch.phase_prediction_sigma_m(1,1)-0.1) < 1e-12);
fprintf('test_predicted_phase_metadata PASS (%d selected records)\n', ...
    metadata.selected_records);
end
