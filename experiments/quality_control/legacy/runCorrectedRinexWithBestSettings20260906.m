function manifest = runCorrectedRinexWithBestSettings20260906()
% Re-run the previously selected best settings with only the observation
% RINEX replaced by user-provided pseudorange-multipath-corrected RINEX.
% All frequency selections and processing parameters come from the saved
% best settings.mat files.
global STOP_CALC
STOP_CALC = 0;
root = '../RESULTS/PPP_CORRECTED_BEST_20260906';
specs(1) = struct('id','K80','settings', ...
    '../RESULTS/PPP_RAW_OPT_20260904/K80/GNSS00GEO_R_20261160237_60M_01S_MO/A9-full_04-Sep-2026_11h56m16s/settings.mat', ...
    'obs','D:/Project/Data/Correction_data/2026.4.26/K80/Arna_results/GNSS00GEO_R_20261160237_60M_01S_MO/preprocessing/pseudorange multipath correction/GNSS00GEO_R_20261160237_60M_01S_MO-multipath corrected.rnx', ...
    'truth',[-1325190.567018 5323275.584479 3243843.319175]);
specs(2) = struct('id','X6','settings', ...
    '../RESULTS/GREC-findx6/X111/GNSS00GEO_R_20261160237_60M_01S_MO/UU_03-Sep-2026_12h30m50s/settings.mat', ...
    'obs','D:/Project/Data/Correction_data/2026.4.26/Findx6/Arna_results/GNSS00GEO_R_20261160237_60M_01S_MO/preprocessing/pseudorange multipath correction/GNSS00GEO_R_20261160237_60M_01S_MO-multipath corrected.rnx', ...
    'truth',[-1325190.552855 5323275.744105 3243843.128584]);
specs(3) = struct('id','ACE5','settings', ...
    '../RESULTS/PPP_RAW_OPT_20260904/ACE5/GNSS00GEO_R_20261160237_59M_01S_MO/A10-full_04-Sep-2026_11h58m25s/settings.mat', ...
    'obs','D:/Project/Data/Correction_data/2026.4.26/ACE5/Arna_results/GNSS00GEO_R_20261160237_59M_01S_MO/preprocessing/pseudorange multipath correction/GNSS00GEO_R_20261160237_59M_01S_MO-multipath corrected.rnx', ...
    'truth',[-1325190.560140 5323275.670612 3243843.217404]);
if ~exist(root,'dir'), mkdir(root); end
rows = {};
for i = 1:numel(specs)
    if ~exist(specs(i).obs,'file'), error('Corrected RINEX not found: %s',specs(i).obs); end
    S = load(specs(i).settings,'settings'); s = S.settings;
    old_obs = s.INPUT.file_obs;
    s.INPUT.file_obs = specs(i).obs;
    s.PROC.name = sprintf('PPP_CORRECTED_BEST_20260906/%s',specs(i).id);
    s.INPUT.bool_batch = true; s.INPUT.bool_parfor = false;
    fprintf('CORRECTED_START %s\nInput: %s\nPrevious input: %s\n',specs(i).id,s.INPUT.file_obs,old_obs);
    logtext = evalc('out = PPP_main(s);');
    fid = fopen(fullfile(out.PROC.output_dir,'processing_console.txt'),'w');
    if fid >= 0, fwrite(fid,logtext); fclose(fid); end
    m = calcMetrics(fullfile(out.PROC.output_dir,'data4plot.mat'),specs(i).truth);
    rows(end+1,:) = {specs(i).id,m.epochs,m.valid_pct,m.p50_3d,m.p95_3d,m.p50_h,...
        m.p95_h,m.p50_u,m.p95_u,m.gt100,char(out.PROC.output_dir),specs(i).obs}; %#ok<AGROW>
    fprintf('CORRECTED_DONE %s epochs=%d valid=%.2f p50=%.3f p95=%.3f\n',...
        specs(i).id,m.epochs,m.valid_pct,m.p50_3d,m.p95_3d);
end
manifest = cell2table(rows,'VariableNames',{'device','epochs','valid_pct','p50_3d_m',...
    'p95_3d_m','p50_h_m','p95_h_m','p50_u_m','p95_u_m','gt100_pct','output_dir','input_obs'});
stamp = datestr(now,'yyyymmdd_HHMMSS');
writetable(manifest,fullfile(root,['manifest_' stamp '.csv']));
save(fullfile(root,['manifest_' stamp '.mat']),'manifest');
disp(manifest);
end

function m = calcMetrics(file,truth)
S = load(file,'storeData'); D = S.storeData; p = D.param(:,1:3);
g = logical(D.float(:)) & all(isfinite(p),2) & all(p~=0,2); dd = p-truth;
e = sqrt(sum(dd.^2,2)); [lat,lon] = xyz2ell(truth);
E = -sin(lon)*dd(:,1)+cos(lon)*dd(:,2);
N = -sin(lat)*cos(lon)*dd(:,1)-sin(lat)*sin(lon)*dd(:,2)+cos(lat)*dd(:,3);
U = cos(lat)*cos(lon)*dd(:,1)+cos(lat)*sin(lon)*dd(:,2)+sin(lat)*dd(:,3);
H = hypot(E,N);
m = struct('epochs',numel(g),'valid_pct',100*mean(g),'p50_3d',median(e(g)),...
    'p95_3d',prctile(e(g),95),'p50_h',median(H(g)),'p95_h',prctile(H(g),95),...
    'p50_u',median(abs(U(g))),'p95_u',prctile(abs(U(g)),95),...
    'gt100',100*mean(e(g)>100));
end
