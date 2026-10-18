function manifest = runK80QualityGatedDopplerMultipath20260924()
% Full-epoch K80 comparison using the combined observation file:
% Doppler-predicted phase + external pseudorange multipath correction.
% The latest metadata/quality gate is applied at PPP ingestion.

global STOP_CALC
STOP_CALC = 0;
root = '../RESULTS/PPP_K80_QUALITY_GATED_DOPPLER_MP_20260924';
if ~exist(root,'dir'); mkdir(root); end

data = 'D:/Project/Data/Correction_data/2026.4.26/K80/Arna_results/GNSS00GEO_R_20261160237_60M_01S_MO/preprocessing';
settings_file = '../RESULTS/PPP_RAW_OPT_20260904/K80/GNSS00GEO_R_20261160237_60M_01S_MO/A9-full_04-Sep-2026_11h56m16s/settings.mat';
obs_file = [data '/pseudorange multipath correction/GNSS00GEO_R_20261160237_60M_01S_MO-doppler predicted-multipath corrected.rnx'];
metadata_file = [data '/doppler prediction/GNSS00GEO_R_20261160237_60M_01S_MO-doppler-predicted.prediction.csv'];
quality_file = [data '/doppler prediction/GNSS00GEO_R_20261160237_60M_01S_MO-doppler-predicted.prediction_error_rms.csv'];
truth = [-1325190.567018 5323275.584479 3243843.319175];

assert(isfile(obs_file),'Combined observation file not found: %s',obs_file);
assert(isfile(metadata_file),'Prediction metadata not found: %s',metadata_file);
assert(isfile(quality_file),'Prediction quality file not found: %s',quality_file);

references = { ...
    'raw_baseline','../RESULTS/PPP_RAW_OPT_20260904/K80/GNSS00GEO_R_20261160237_60M_01S_MO/A9-full_04-Sep-2026_11h56m16s/data4plot.mat'; ...
    'multipath_only','../RESULTS/PPP_CORRECTED_BEST_20260906/GNSS00GEO_R_20261160237_60M_01S_MO-multipath corrected/K80_06-Sep-2026_20h41m17s/data4plot.mat'; ...
    'quality_gated_prediction_only','../RESULTS/PPP_QUALITY_GATED_PREDICTION_20260924/GNSS00GEO_R_20261160237_60M_01S_MO-doppler predicted/K80_ALL_QRMS_1p0_24-Sep-2026_12h09m47s/data4plot.mat'};

rows = {};
for i = 1:size(references,1)
    m = calcMetrics(references{i,2},truth);
    rows(end+1,:) = metricRow(references{i,1},NaN,m,0,0,0,references{i,2}); %#ok<AGROW>
end

S = load(settings_file,'settings'); base = S.settings;
scales = [1.0 1.5];
for i = 1:numel(scales)
    s = base;
    s.INPUT.file_obs = obs_file;
    s.INPUT.bool_batch = true;
    % Suppress GUI waitbars so the reproducible full-epoch run also works
    % under MATLAB -batch. PPP_main itself remains sequential here.
    s.INPUT.bool_parfor = true;
    variant = sprintf('quality_gated_doppler_mp_%.1fx',scales(i));
    s.PROC.name = sprintf('PPP_K80_QUALITY_GATED_DOPPLER_MP_20260924/%s',strrep(variant,'.','p'));
    s.PROC.predicted_phase.enable = true;
    s.PROC.predicted_phase.metadata_file = metadata_file;
    s.PROC.predicted_phase.max_prediction_length = 1;
    s.PROC.predicted_phase.sigma_scale = 1;
    s.PROC.predicted_phase.sigma_floor_m = 0.03;
    s.PROC.predicted_phase.time_tolerance_ms = 2;
    s.PROC.predicted_phase.exclude_from_cycle_slip = true;
    s.PROC.predicted_phase.allowed_signals = {};
    s.PROC.predicted_phase.quality_rms_file = quality_file;
    s.PROC.predicted_phase.quality_max_rms_m = 0.5;
    s.PROC.predicted_phase.quality_sigma_scale = scales(i);
    s.PROC.predicted_phase.quality_min_samples = 10;
    s.PROC.predicted_phase.reject_if_quality_missing = true;

    fprintf('K80_QG_DOPPLER_MP_START scale=%.1f\nInput: %s\n',scales(i),obs_file);
    logtext = evalc('out = PPP_main(s);');
    fid = fopen(fullfile(out.PROC.output_dir,'processing_console.txt'),'w');
    if fid >= 0; fwrite(fid,logtext); fclose(fid); end
    result_file = fullfile(out.PROC.output_dir,'data4plot.mat');
    m = calcMetrics(result_file,truth);
    c = predictionCounts(result_file);
    rows(end+1,:) = metricRow(variant,scales(i),m,c.predicted,c.rejected,c.cs_suppressed,char(out.PROC.output_dir)); %#ok<AGROW>
    fprintf('K80_QG_DOPPLER_MP_DONE scale=%.1f valid=%.3f N/E/H=%.3f/%.3f/%.3f P50/P95=%.3f/%.3f pred=%d\n', ...
        scales(i),m.valid_pct,m.rms_n,m.rms_e,m.rms_h,m.p50_3d,m.p95_3d,c.predicted);
end

manifest = cell2table(rows,'VariableNames',{'variant','quality_sigma_scale','epochs','valid_epochs','valid_pct', ...
    'rms_n_m','p95_n_m','rms_e_m','p95_e_m','rms_h_m','p95_h_m','p50_3d_m','p95_3d_m', ...
    'mapped_predicted_observations','rejected_predicted_observations','cs_suppressed_sat_epochs','output_dir'});
stamp = datestr(now,'yyyymmdd_HHMMSS');
writetable(manifest,fullfile(root,['manifest_' stamp '.csv']));
save(fullfile(root,['manifest_' stamp '.mat']),'manifest');
disp(manifest);
end

function row = metricRow(name,scale,m,pred,rejected,suppressed,outdir)
row = {name,scale,m.epochs,m.valid_epochs,m.valid_pct,m.rms_n,m.p95_n,m.rms_e,m.p95_e, ...
    m.rms_h,m.p95_h,m.p50_3d,m.p95_3d,pred,rejected,suppressed,outdir};
end

function c = predictionCounts(file)
S=load(file,'storeData'); D=S.storeData;
c.predicted=nnz(D.phase_predicted_freq);
c.rejected=nnz(D.phase_prediction_rejected_freq);
c.cs_suppressed=nnz(D.phase_prediction_cs_suppressed);
end

function m = calcMetrics(file,truth)
S=load(file,'storeData'); D=S.storeData; p=D.param(:,1:3);
g=logical(D.float(:)) & all(isfinite(p),2) & all(p~=0,2);
dd=p-truth; [lat,lon]=xyz2ell(truth);
E=-sin(lon)*dd(:,1)+cos(lon)*dd(:,2);
N=-sin(lat)*cos(lon)*dd(:,1)-sin(lat)*sin(lon)*dd(:,2)+cos(lat)*dd(:,3);
H=cos(lat)*cos(lon)*dd(:,1)+cos(lat)*sin(lon)*dd(:,2)+sin(lat)*dd(:,3);
e3=sqrt(N.^2+E.^2+H.^2);
m=struct('epochs',numel(g),'valid_epochs',nnz(g),'valid_pct',100*mean(g), ...
    'rms_n',sqrt(mean(N(g).^2)),'p95_n',prctile(abs(N(g)),95), ...
    'rms_e',sqrt(mean(E(g).^2)),'p95_e',prctile(abs(E(g)),95), ...
    'rms_h',sqrt(mean(H(g).^2)),'p95_h',prctile(abs(H(g)),95), ...
    'p50_3d',median(e3(g)),'p95_3d',prctile(e3(g),95));
end
