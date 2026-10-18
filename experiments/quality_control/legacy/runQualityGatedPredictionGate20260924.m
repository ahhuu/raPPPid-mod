function manifest = runQualityGatedPredictionGate20260924()
% Full-epoch non-combined PPP gate with device-specific signal whitelist and
% satellite/frequency/prediction-length RMS based stochastic model.

global STOP_CALC
STOP_CALC = 0;
root = '../RESULTS/PPP_QUALITY_GATED_PREDICTION_20260924';
if ~exist(root,'dir'); mkdir(root); end
specs = buildSpecs();
variants = buildVariants();
rows = {};

for i = 1:numel(specs)
    S = load(specs(i).settings,'settings'); base_settings = S.settings;
    base = calcMetrics(specs(i).baseline, specs(i).truth);
    vv = variants(strcmp({variants.device},specs(i).device));
    for j = 1:numel(vv)
        s = base_settings;
        s.INPUT.file_obs = specs(i).obs;
        s.INPUT.bool_batch = true; s.INPUT.bool_parfor = false;
        s.PROC.name = sprintf('PPP_QUALITY_GATED_PREDICTION_20260924/%s_%s', ...
            specs(i).device, vv(j).name);
        s.PROC.predicted_phase.enable = true;
        s.PROC.predicted_phase.metadata_file = specs(i).metadata;
        s.PROC.predicted_phase.max_prediction_length = 1;
        s.PROC.predicted_phase.sigma_scale = 1;
        s.PROC.predicted_phase.sigma_floor_m = 0.03;
        s.PROC.predicted_phase.time_tolerance_ms = 2;
        s.PROC.predicted_phase.exclude_from_cycle_slip = true;
        s.PROC.predicted_phase.allowed_signals = vv(j).allowed_signals;
        s.PROC.predicted_phase.quality_rms_file = specs(i).quality;
        s.PROC.predicted_phase.quality_max_rms_m = 0.5;
        s.PROC.predicted_phase.quality_sigma_scale = vv(j).quality_sigma_scale;
        s.PROC.predicted_phase.quality_min_samples = 10;
        s.PROC.predicted_phase.reject_if_quality_missing = true;

        fprintf('QUALITY_GATE_START %s %s\n', specs(i).device, vv(j).name);
        logtext = evalc('out = PPP_main(s);');
        fid = fopen(fullfile(out.PROC.output_dir,'processing_console.txt'),'w');
        if fid >= 0; fwrite(fid,logtext); fclose(fid); end
        result_file = fullfile(out.PROC.output_dir,'data4plot.mat');
        candidate = calcMetrics(result_file,specs(i).truth);
        counts = predictionCounts(result_file);
        rows(end+1,:) = {specs(i).device,vv(j).name,vv(j).quality_sigma_scale, ...
            strjoin(string(vv(j).allowed_signals),','),base.valid_pct,base.rms_n,base.rms_e,base.rms_h,base.p50_3d,base.p95_3d, ...
            candidate.valid_pct,candidate.rms_n,candidate.rms_e,candidate.rms_h,candidate.p50_3d,candidate.p95_3d, ...
            counts.predicted,counts.rejected,counts.cs_suppressed,char(out.PROC.output_dir)}; %#ok<AGROW>
        fprintf('QUALITY_GATE_DONE %s %s valid=%.3f N/E/H=%.3f/%.3f/%.3f P50/P95=%.3f/%.3f pred=%d\n', ...
            specs(i).device,vv(j).name,candidate.valid_pct,candidate.rms_n,candidate.rms_e,candidate.rms_h, ...
            candidate.p50_3d,candidate.p95_3d,counts.predicted);
    end
end

manifest = cell2table(rows,'VariableNames',{ ...
    'device','variant','quality_sigma_scale','allowed_signals', ...
    'base_valid_pct','base_rms_n_m','base_rms_e_m','base_rms_h_m','base_p50_3d_m','base_p95_3d_m', ...
    'pred_valid_pct','pred_rms_n_m','pred_rms_e_m','pred_rms_h_m','pred_p50_3d_m','pred_p95_3d_m', ...
    'mapped_predicted_observations','rejected_predicted_observations','cs_suppressed_sat_epochs','output_dir'});
stamp = datestr(now,'yyyymmdd_HHMMSS');
writetable(manifest,fullfile(root,['manifest_' stamp '.csv']));
save(fullfile(root,['manifest_' stamp '.mat']),'manifest');
disp(manifest);
end

function v = buildVariants()
all = {};
wl = {'C:L5P','E:L5Q','G:L5Q','R:L1C'};
v(1)=struct('device','K80','name','ALL_QRMS_1p0','quality_sigma_scale',1.0,'allowed_signals',{all});
v(2)=struct('device','K80','name','ALL_QRMS_1p5','quality_sigma_scale',1.5,'allowed_signals',{all});
v(3)=struct('device','X6','name','WL_QRMS_1p0','quality_sigma_scale',1.0,'allowed_signals',{wl});
v(4)=struct('device','X6','name','WL_QRMS_1p5','quality_sigma_scale',1.5,'allowed_signals',{wl});
v(5)=struct('device','ACE5','name','ALL_QRMS_1p5','quality_sigma_scale',1.5,'allowed_signals',{all});
v(6)=struct('device','ACE5','name','ALL_QRMS_2p0','quality_sigma_scale',2.0,'allowed_signals',{all});
end

function specs = buildSpecs()
data = 'D:/Project/Data/Correction_data/2026.4.26';
specs(1)=makeSpec('K80','../RESULTS/PPP_RAW_OPT_20260904/K80/GNSS00GEO_R_20261160237_60M_01S_MO/A9-full_04-Sep-2026_11h56m16s', ...
    [data '/K80/Arna_results/GNSS00GEO_R_20261160237_60M_01S_MO/preprocessing/doppler prediction/GNSS00GEO_R_20261160237_60M_01S_MO-doppler predicted.rnx'], ...
    [-1325190.567018 5323275.584479 3243843.319175]);
specs(2)=makeSpec('X6','../RESULTS/GREC-findx6/X111/GNSS00GEO_R_20261160237_60M_01S_MO/UU_03-Sep-2026_12h30m50s', ...
    [data '/Findx6/Arna_results/GNSS00GEO_R_20261160237_60M_01S_MO/preprocessing/doppler prediction/GNSS00GEO_R_20261160237_60M_01S_MO-doppler predicted.rnx'], ...
    [-1325190.552855 5323275.744105 3243843.128584]);
specs(3)=makeSpec('ACE5','../RESULTS/PPP_RAW_OPT_20260904/ACE5/GNSS00GEO_R_20261160237_59M_01S_MO/A10-full_04-Sep-2026_11h58m25s', ...
    [data '/ACE5/Arna_results/GNSS00GEO_R_20261160237_59M_01S_MO/preprocessing/doppler prediction/GNSS00GEO_R_20261160237_59M_01S_MO-doppler predicted.rnx'], ...
    [-1325190.560140 5323275.670612 3243843.217404]);
end

function s = makeSpec(device,result_dir,obs_file,truth)
[folder,name]=fileparts(obs_file);
stem=strrep(name,'-doppler predicted','-doppler-predicted');
s=struct('device',device,'settings',[result_dir '/settings.mat'],'baseline',[result_dir '/data4plot.mat'], ...
    'obs',obs_file,'metadata',strrep(fullfile(folder,[stem '.prediction.csv']),'\','/'), ...
    'quality',strrep(fullfile(folder,[stem '.prediction_error_rms.csv']),'\','/'),'truth',truth);
end

function c = predictionCounts(file)
S=load(file,'storeData'); D=S.storeData;
c.predicted=nnz(D.phase_predicted_freq); c.rejected=nnz(D.phase_prediction_rejected_freq);
c.cs_suppressed=nnz(D.phase_prediction_cs_suppressed);
end

function m = calcMetrics(file,truth)
S=load(file,'storeData'); D=S.storeData; p=D.param(:,1:3);
g=logical(D.float(:)) & all(isfinite(p),2) & all(p~=0,2); dd=p-truth; [lat,lon]=xyz2ell(truth);
E=-sin(lon)*dd(:,1)+cos(lon)*dd(:,2);
N=-sin(lat)*cos(lon)*dd(:,1)-sin(lat)*sin(lon)*dd(:,2)+cos(lat)*dd(:,3);
H=cos(lat)*cos(lon)*dd(:,1)+cos(lat)*sin(lon)*dd(:,2)+sin(lat)*dd(:,3); e3=sqrt(N.^2+E.^2+H.^2);
m=struct('valid_pct',100*mean(g),'rms_n',sqrt(mean(N(g).^2)),'rms_e',sqrt(mean(E(g).^2)), ...
    'rms_h',sqrt(mean(H(g).^2)),'p50_3d',median(e3(g)),'p95_3d',prctile(e3(g),95));
end
