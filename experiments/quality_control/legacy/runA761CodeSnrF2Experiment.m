function manifest = runA761CodeSnrF2Experiment(variant_ids)
% Run full-600-epoch A761 frequency-2 raw-code SNR experiments.

global STOP_CALC %#ok<GVMIS>
STOP_CALC = 0;

if nargin < 1 || isempty(variant_ids)
    variant_ids = {'B0','B05','B10','B15','B20'};
end
if ischar(variant_ids) || isstring(variant_ids)
    variant_ids = cellstr(variant_ids);
end

template_file = ['../RESULTS/GREC-ACE5/A761/' ...
    'GNSS00GEO_R_20260760533_20M_01S_MO/' ...
    '10min_08-Aug-2026_20h34m49s/settings.mat'];
report_dir = ['../RESULTS/GREC-ACE5/A761/' ...
    'GNSS00GEO_R_20260760533_20M_01S_MO/C2SNR_A761_20260902'];
if ~exist(report_dir, 'dir'); mkdir(report_dir); end

variants = experimentVariants();
rows = {};
for k = 1:numel(variant_ids)
    id = char(variant_ids{k});
    idx = find(strcmp({variants.id}, id), 1);
    assert(~isempty(idx), 'Unknown C2 SNR variant: %s', id);
    v = variants(idx);

    Q = load(template_file, 'settings');
    settings = Q.settings;
    settings.PROC.name = sprintf('GREC-ACE5/A761/C2SNR-A761-%s', id);
    settings.PROC.epochs = [1 600];
    settings.PROC.timeFrame = [1 600];
    settings.PROC.timeFrameFrom = '1';
    settings.PROC.timeFrameTo = '600';
    settings.PROC.timeSpan_format_epochs = true;
    settings.PROC.timeSpan_format_time = false;
    settings.PROC.timeSpan_format_SOD = false;
    settings.PROC.timeSpan_format_HOD = false;
    settings.INPUT.bool_batch = true;
    settings.INPUT.bool_parfor = false;
    settings.ADJ.code_snr_f2 = makeConfig(v);

    fprintf('C2SNR_START variant=%s low_std=%.2f systems=%s\n', ...
        id, v.low_std, v.systems);
    started = datetime('now');
    processing_log = evalc('out = PPP_main(settings);');
    finished = datetime('now');
    log_file = fullfile(out.PROC.output_dir, 'processing_console.txt');
    file_id = fopen(log_file, 'w');
    if file_id >= 0
        cleanup = onCleanup(@() fclose(file_id));
        fprintf(file_id, '%s', processing_log);
        clear cleanup;
    end
    metrics = calculateFullMetrics(fullfile(out.PROC.output_dir, 'data4plot.mat'));
    rows(end+1,:) = {id, v.low_std, v.systems, metrics.N_cm, ...
        metrics.E_cm, metrics.H_cm, metrics.valid_epochs, ...
        char(out.PROC.output_dir), char(started), char(finished)}; %#ok<AGROW>
    fprintf('C2SNR_DONE %s N/E/H=%.3f/%.3f/%.3f cm dir=%s\n', ...
        id, metrics.N_cm, metrics.E_cm, metrics.H_cm, out.PROC.output_dir);
end

manifest = cell2table(rows, 'VariableNames', ...
    {'variant','low_std_m','systems','N_cm','E_cm','H_cm', ...
     'valid_epochs','output_dir','started','finished'});
manifest_file = fullfile(report_dir, 'c2snr_manifest.csv');
if exist(manifest_file, 'file')
    old = readtable(manifest_file, 'TextType', 'string');
    manifest = [old; manifest];
end
writetable(manifest, manifest_file);
save(fullfile(report_dir, 'c2snr_manifest.mat'), 'manifest', ...
    'template_file', 'variants');
disp(manifest(:, {'variant','low_std_m','systems','N_cm','E_cm','H_cm','valid_epochs'}));
end


function variants = experimentVariants()
variants = struct( ...
    'id', {'B0','B05','B10','B15','B20', ...
           'GPS05','GAL05','BDS05','GPS10','GAL10','BDS10', ...
           'GPS20','GAL20','BDS20', ...
           'GPS025','GPS030','GPS035','GPS040','GPS045'}, ...
    'enable', {false,true,true,true,true, true,true,true,true,true,true,true,true,true, ...
               true,true,true,true,true}, ...
    'low_std', {0,0.5,1.0,1.5,2.0, 0.5,0.5,0.5,1.0,1.0,1.0,2.0,2.0,2.0, ...
                0.25,0.30,0.35,0.40,0.45}, ...
    'systems', {'ALL','ALL','ALL','ALL','ALL', ...
                'GPS','GAL','BDS','GPS','GAL','BDS','GPS','GAL','BDS', ...
                'GPS','GPS','GPS','GPS','GPS'});
end


function cfg = makeConfig(v)
all_on = strcmp(v.systems, 'ALL');
cfg = struct('enable',v.enable, 'low_snr',30, 'high_snr',40, ...
    'low_std',max(v.low_std, eps), 'missing_snr','base', ...
    'systems',struct( ...
        'GPS',all_on || strcmp(v.systems,'GPS'), ...
        'GLO',false, ...
        'GAL',all_on || strcmp(v.systems,'GAL'), ...
        'BDS',all_on || strcmp(v.systems,'BDS'), ...
        'QZSS',false));
end


function metrics = calculateFullMetrics(data_file)
D = load(data_file, 'storeData');
xyz_true = [-1325727.637145 5323473.208546 3243297.012607];
pos_geo_true = cart2geo(xyz_true);
[north_true, east_true] = ell2utm_GT(pos_geo_true.lat, pos_geo_true.lon);
truth = [north_true, east_true, pos_geo_true.h];
delta = D.storeData.posFloat_utm - truth;
rms_m = nan(1,3);
valid = true(size(delta,1),1);
for j = 1:3
    use = delta(:,j) ~= 0 & isfinite(delta(:,j));
    valid = valid & use;
    rms_m(j) = sqrt(mean(delta(use,j).^2));
end
metrics = struct('N_cm',100*rms_m(1), 'E_cm',100*rms_m(2), ...
    'H_cm',100*rms_m(3), 'valid_epochs',sum(valid));
end
