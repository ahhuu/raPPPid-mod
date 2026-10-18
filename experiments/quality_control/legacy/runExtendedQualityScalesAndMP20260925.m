function [scale_manifest, mp_manifest, winners] = runExtendedQualityScalesAndMP20260925()
% Extend the quality-RMS sigma-scale test to 5x/10x/15x/20x, then run
% each device's winning scale on the Doppler-predicted + MP-corrected RINEX.
global STOP_CALC
STOP_CALC = 0;
root = '../RESULTS/PPP_QUALITY_GATE_EXTENDED_20260925';
if ~exist(root,'dir'), mkdir(root); end
specs = buildSpecs();
new_scales = [5 10 15 20];
scale_rows = {};

for i = 1:numel(specs)
    S = load(specs(i).settings,'settings');
    base = calcMetrics(specs(i).baseline,specs(i).truth);
    for scale = new_scales
        s = configure(S.settings,specs(i).pred_obs,specs(i),scale);
        tag = sprintf('%02dx',scale);
        s.PROC.name = sprintf('PPP_QUALITY_GATE_EXTENDED_20260925/%s_PRED_%s',specs(i).device,tag);
        fprintf('QEXT_START %s %.1f\n',specs(i).device,scale);
        logtext = evalc('out=PPP_main(s);');
        saveConsole(out.PROC.output_dir,logtext);
        file = fullfile(out.PROC.output_dir,'data4plot.mat');
        m = calcMetrics(file,specs(i).truth); c = predictionCounts(file);
        scale_rows(end+1,:) = resultRow(specs(i).device,scale,base,m,c,out.PROC.output_dir,specs(i).pred_obs); %#ok<AGROW>
        fprintf('QEXT_DONE %s %.1f valid=%.3f N/E/H=%.3f/%.3f/%.3f P50/P95=%.3f/%.3f\n',specs(i).device,scale,m.valid_pct,m.rms_n,m.rms_e,m.rms_h,m.p50_3d,m.p95_3d);
    end
end
names = {'device','quality_sigma_scale','base_valid_pct','base_rms_n_m','base_rms_e_m','base_rms_h_m','base_p50_3d_m','base_p95_3d_m','valid_pct','rms_n_m','rms_e_m','rms_h_m','p50_3d_m','p95_3d_m','rms_3d_components_m','mapped_predicted_observations','rejected_predicted_observations','cs_suppressed_sat_epochs','output_dir','input_obs'};
scale_manifest = cell2table(scale_rows,'VariableNames',names);
stamp = datestr(now,'yyyymmdd_HHMMSS');
writetable(scale_manifest,fullfile(root,['extended_scales_' stamp '.csv']));
save(fullfile(root,['extended_scales_' stamp '.mat']),'scale_manifest');

% Existing 1x/2x/3x full-epoch results, used together with the new tests to
% select the minimum component-wise 3-D RMS norm. Valid-rate loss >0.2% is
% disallowed before comparing RMS.
old = existingResults();
winners = table('Size',[numel(specs),4], ...
    'VariableTypes',{'string','double','double','double'}, ...
    'VariableNames',{'device','quality_sigma_scale','valid_pct','rms_3d_components_m'});
for i = 1:numel(specs)
    dnew = scale_manifest(strcmp(scale_manifest.device,specs(i).device),:);
    dold = old(strcmp(old.device,specs(i).device),:);
    allr = [dold(:,{'device','quality_sigma_scale','valid_pct','rms_n_m','rms_e_m','rms_h_m'}); dnew(:,{'device','quality_sigma_scale','valid_pct','rms_n_m','rms_e_m','rms_h_m'})];
    allr.rms_3d_components_m = sqrt(allr.rms_n_m.^2 + allr.rms_e_m.^2 + allr.rms_h_m.^2);
    keep = allr.valid_pct >= max(allr.valid_pct)-0.2;
    eligible = allr(keep,:);
    [~,k] = min(eligible.rms_3d_components_m);
    win = eligible(k,:);
    winners.device(i) = string(specs(i).device);
    winners.quality_sigma_scale(i) = win.quality_sigma_scale;
    winners.valid_pct(i) = win.valid_pct;
    winners.rms_3d_components_m(i) = win.rms_3d_components_m;
    fprintf('QEXT_WINNER %s %.1f valid=%.3f RMS3=%.3f\n',specs(i).device,win.quality_sigma_scale,win.valid_pct,win.rms_3d_components_m);
end
writetable(winners,fullfile(root,['winners_' stamp '.csv']));

mp_rows = {};
for i = 1:numel(specs)
    S = load(specs(i).settings,'settings');
    scale = winners.quality_sigma_scale(i);
    s = configure(S.settings,specs(i).mp_obs,specs(i),scale);
    tag = strrep(sprintf('%.1f',scale),'.','p');
    s.PROC.name = sprintf('PPP_QUALITY_GATE_EXTENDED_20260925/%s_PRED_MP_QRMS_%s',specs(i).device,tag);
    fprintf('QEXT_MP_START %s %.1f\n',specs(i).device,scale);
    logtext = evalc('out=PPP_main(s);');
    saveConsole(out.PROC.output_dir,logtext);
    file = fullfile(out.PROC.output_dir,'data4plot.mat');
    base = calcMetrics(specs(i).baseline,specs(i).truth);
    m = calcMetrics(file,specs(i).truth); c = predictionCounts(file);
    mp_rows(end+1,:) = resultRow(specs(i).device,scale,base,m,c,out.PROC.output_dir,specs(i).mp_obs); %#ok<AGROW>
    fprintf('QEXT_MP_DONE %s %.1f valid=%.3f N/E/H=%.3f/%.3f/%.3f P50/P95=%.3f/%.3f\n',specs(i).device,scale,m.valid_pct,m.rms_n,m.rms_e,m.rms_h,m.p50_3d,m.p95_3d);
end
mp_manifest = cell2table(mp_rows,'VariableNames',names);
stamp2 = datestr(now,'yyyymmdd_HHMMSS');
writetable(mp_manifest,fullfile(root,['winning_scale_mp_' stamp2 '.csv']));
save(fullfile(root,['winning_scale_mp_' stamp2 '.mat']),'mp_manifest','winners');
disp(scale_manifest); disp(winners); disp(mp_manifest);
end

function s = configure(s,obs,spec,scale)
s.INPUT.file_obs = obs; s.INPUT.bool_batch = true; s.INPUT.bool_parfor = false;
s.PROC.predicted_phase.enable = true;
s.PROC.predicted_phase.metadata_file = spec.metadata;
s.PROC.predicted_phase.max_prediction_length = 1;
s.PROC.predicted_phase.sigma_scale = 1;
s.PROC.predicted_phase.sigma_floor_m = .03;
s.PROC.predicted_phase.time_tolerance_ms = 2;
s.PROC.predicted_phase.exclude_from_cycle_slip = true;
s.PROC.predicted_phase.allowed_signals = {};
s.PROC.predicted_phase.quality_rms_file = spec.quality;
s.PROC.predicted_phase.quality_max_rms_m = .5;
s.PROC.predicted_phase.quality_sigma_scale = scale;
s.PROC.predicted_phase.quality_min_samples = 10;
s.PROC.predicted_phase.reject_if_quality_missing = true;
end

function row = resultRow(device,scale,base,m,c,outdir,obs)
row = {device,scale,base.valid_pct,base.rms_n,base.rms_e,base.rms_h,base.p50_3d,base.p95_3d,m.valid_pct,m.rms_n,m.rms_e,m.rms_h,m.p50_3d,m.p95_3d,sqrt(m.rms_n^2+m.rms_e^2+m.rms_h^2),c.predicted,c.rejected,c.cs_suppressed,char(outdir),obs};
end

function old = existingResults()
rows = {
 'K80',1,99.944,1.941,2.914,4.628; 'K80',2,99.944,1.9417,2.9118,4.6347; 'K80',3,99.944,1.9415,2.9113,4.6348;
 'X6',1,100,2.0804,4.9143,11.811; 'X6',2,100,2.0806,4.9117,11.805; 'X6',3,100,2.0812,4.9124,11.800;
 'ACE5',1,99.780,3.6968,14.941,26.048; 'ACE5',2,99.868,3.697,14.925,26.010; 'ACE5',3,99.868,3.699,14.912,25.987};
old = cell2table(rows,'VariableNames',{'device','quality_sigma_scale','valid_pct','rms_n_m','rms_e_m','rms_h_m'});
end

function specs = buildSpecs()
d = 'D:/Project/Data/Correction_data/2026.4.26';
specs(1) = makeSpec('K80','../RESULTS/PPP_RAW_OPT_20260904/K80/GNSS00GEO_R_20261160237_60M_01S_MO/A9-full_04-Sep-2026_11h56m16s',[d '/K80/Arna_results/GNSS00GEO_R_20261160237_60M_01S_MO'],'GNSS00GEO_R_20261160237_60M_01S_MO',[-1325190.567018 5323275.584479 3243843.319175]);
specs(2) = makeSpec('X6','../RESULTS/GREC-findx6/X111/GNSS00GEO_R_20261160237_60M_01S_MO/UU_03-Sep-2026_12h30m50s',[d '/Findx6/Arna_results/GNSS00GEO_R_20261160237_60M_01S_MO'],'GNSS00GEO_R_20261160237_60M_01S_MO',[-1325190.552855 5323275.744105 3243843.128584]);
specs(3) = makeSpec('ACE5','../RESULTS/PPP_RAW_OPT_20260904/ACE5/GNSS00GEO_R_20261160237_59M_01S_MO/A10-full_04-Sep-2026_11h58m25s',[d '/ACE5/Arna_results/GNSS00GEO_R_20261160237_59M_01S_MO'],'GNSS00GEO_R_20261160237_59M_01S_MO',[-1325190.560140 5323275.670612 3243843.217404]);
end

function s = makeSpec(device,result_dir,data_dir,stem,truth)
pred_dir = [data_dir '/preprocessing/doppler prediction'];
mp_dir = [data_dir '/preprocessing/pseudorange multipath correction'];
s = struct('device',device,'settings',[result_dir '/settings.mat'],'baseline',[result_dir '/data4plot.mat'], ...
 'pred_obs',[pred_dir '/' stem '-doppler predicted.rnx'], ...
 'mp_obs',[mp_dir '/' stem '-doppler predicted-multipath corrected.rnx'], ...
 'metadata',[pred_dir '/' stem '-doppler-predicted.prediction.csv'], ...
 'quality',[pred_dir '/' stem '-doppler-predicted.prediction_error_rms.csv'],'truth',truth);
end

function saveConsole(outdir,txt)
fid = fopen(fullfile(outdir,'processing_console.txt'),'w');
if fid >= 0, fwrite(fid,txt); fclose(fid); end
end

function c = predictionCounts(file)
S = load(file,'storeData'); D = S.storeData;
c.predicted = nnz(D.phase_predicted_freq); c.rejected = nnz(D.phase_prediction_rejected_freq); c.cs_suppressed = nnz(D.phase_prediction_cs_suppressed);
end

function m = calcMetrics(file,truth)
S = load(file,'storeData'); D = S.storeData; p = D.param(:,1:3);
g = logical(D.float(:)) & all(isfinite(p),2) & all(p~=0,2); dd = p-truth;
[lat,lon] = xyz2ell(truth);
E = -sin(lon)*dd(:,1)+cos(lon)*dd(:,2);
N = -sin(lat)*cos(lon)*dd(:,1)-sin(lat)*sin(lon)*dd(:,2)+cos(lat)*dd(:,3);
H = cos(lat)*cos(lon)*dd(:,1)+cos(lat)*sin(lon)*dd(:,2)+sin(lat)*dd(:,3);
e3 = sqrt(N.^2+E.^2+H.^2);
m = struct('valid_pct',100*mean(g),'rms_n',sqrt(mean(N(g).^2)),'rms_e',sqrt(mean(E(g).^2)),'rms_h',sqrt(mean(H(g).^2)),'p50_3d',median(e3(g)),'p95_3d',prctile(e3(g),95));
end
