function manifest = runResetColdStartAblation20260925()
% Full-epoch 2x2 ablation for periodic float reset and segment cold start.
% All non-target settings are loaded from the selected production baseline.
global STOP_CALC %#ok<GVMIS>
STOP_CALC = 0;

root = '../RESULTS/PPP_RESET_COLDSTART_ABLATION_20260925';
if ~exist(root,'dir'), mkdir(root); end
defs = deviceDefs();
rows = {};
for di = 1:numel(defs)
    d = defs(di);
    B = load(d.template,'settings');
    for reset_on = [false true]
        for cold_start_on = [false true]
            label = sprintf('R%d_C%d',reset_on,cold_start_on);
            s = B.settings;
            s.PROC.name = sprintf('PPP_RESET_COLDSTART_ABLATION_20260925/%s/%s',d.id,label);
            s.INPUT.bool_batch = true;
            s.INPUT.bool_parfor = false;

            % Factor 1: retain the production interval, toggle reset only.
            s.PROC.reset_float = reset_on;
            s.PROC.reset_fixed = false;
            s.PROC.reset_bool_min = true;
            s.PROC.reset_bool_epoch = false;
            s.PROC.reset_after = d.reset_after_min;

            % Factor 2: retain the production cold-start settings, toggle only.
            s.PROC.cold_start.enable = cold_start_on;
            s.PROC.cold_start.mode = 'multi_epoch';
            s.PROC.cold_start.window_epochs = 10;
            s.PROC.cold_start.min_samples = 3;
            s.PROC.cold_start.ambiguity_init = 'median_code_phase';
            s.PROC.cold_start.robust_code = cold_start_on;
            s.PROC.cold_start.huber_c = 1.5;
            s.PROC.cold_start.scale_floor_m = .25;
            s.PROC.cold_start.weight_floor = .05;

            fprintf('ABLATION_START %s %s\n',d.id,label);
            logtext = evalc('out = PPP_main(s);');
            fid = fopen(fullfile(out.PROC.output_dir,'processing_console.txt'),'w');
            if fid >= 0, fwrite(fid,logtext); fclose(fid); end
            m = calcMetrics(fullfile(out.PROC.output_dir,'data4plot.mat'),d.truth);
            rows(end+1,:) = {d.id,label,reset_on,cold_start_on,d.reset_after_min, ...
                m.epochs,m.valid_pct,m.n_rms,m.e_rms,m.h_rms,m.p50_3d,m.p95_3d, ...
                m.gt100,m.cs_epoch,m.cs_obs,char(out.PROC.output_dir)}; %#ok<AGROW>
            fprintf('ABLATION_DONE %s %s valid=%.3f N/E/H=%.3f/%.3f/%.3f P50/P95=%.3f/%.3f\n', ...
                d.id,label,m.valid_pct,m.n_rms,m.e_rms,m.h_rms,m.p50_3d,m.p95_3d);
        end
    end
end
manifest = cell2table(rows,'VariableNames',{'device','variant','reset_float','cold_start', ...
    'reset_after_min','epochs','valid_pct','n_rms_m','e_rms_m','h_rms_m', ...
    'p50_3d_m','p95_3d_m','gt100_pct','cs_epoch_pct','cs_obs_pct','output_dir'});
stamp = datestr(now,'yyyymmdd_HHMMSS');
writetable(manifest,fullfile(root,['manifest_' stamp '.csv']));
save(fullfile(root,['manifest_' stamp '.mat']),'manifest');
disp(manifest);
end

function m = calcMetrics(file,truth)
S = load(file,'storeData'); D = S.storeData; p = D.param(:,1:3);
g = logical(D.float(:)) & all(isfinite(p),2) & all(p~=0,2);
dd = p-truth; [lat,lon] = xyz2ell(truth);
E = -sin(lon)*dd(:,1)+cos(lon)*dd(:,2);
N = -sin(lat)*cos(lon)*dd(:,1)-sin(lat)*sin(lon)*dd(:,2)+cos(lat)*dd(:,3);
U = cos(lat)*cos(lon)*dd(:,1)+cos(lat)*sin(lon)*dd(:,2)+sin(lat)*dd(:,3);
e3 = sqrt(sum(dd.^2,2)); cs = full(D.cs_found)~=0; ph = false(size(cs));
for f = 1:3
    L = full(D.(['L' num2str(f)])); ph = ph | (isfinite(L) & L~=0);
end
m = struct('epochs',numel(g),'valid_pct',100*mean(g),'n_rms',sqrt(mean(N(g).^2)), ...
    'e_rms',sqrt(mean(E(g).^2)),'h_rms',sqrt(mean(U(g).^2)), ...
    'p50_3d',median(e3(g)),'p95_3d',prctile(e3(g),95),'gt100',100*mean(e3(g)>100), ...
    'cs_epoch',100*mean(any(cs,2)),'cs_obs',100*nnz(cs)/max(1,nnz(ph)));
end

function d = deviceDefs()
b = '../RESULTS/PPP_RAW_OPT_20260904/';
d(1) = struct('id','K80','template',[b 'K80/GNSS00GEO_R_20261160237_60M_01S_MO/A9-full_04-Sep-2026_11h56m16s/settings.mat'], ...
    'truth',[-1325190.567018 5323275.584479 3243843.319175],'reset_after_min',1);
d(2) = struct('id','ACE5','template',[b 'ACE5/GNSS00GEO_R_20261160237_59M_01S_MO/A10-full_04-Sep-2026_11h58m25s/settings.mat'], ...
    'truth',[-1325190.560140 5323275.670612 3243843.217404],'reset_after_min',.5);
end
