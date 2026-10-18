function manifest = runRaimMonitorStage2_20260930(devices, epoch_limit, test_model, experiment)
%RUNRAIMMONITORSTAGE2_20260930 Run monitor-only RAIM on each report winner.
%   The winning device-specific settings and observation inputs are loaded
%   directly from the result folders cited in the three-phone shaded PPP
%   report. Only settings.PROC.raim, the output name, and optional epoch end
%   are changed. No RAIM exclusion is applied to the PPP solution.
%   test_model defaults to 'wls_residual'; 'innovation' is retained only
%   for controlled comparison because the PPP innovation covariance can be
%   strongly correlated and nearly singular.

if nargin < 1 || isempty(devices); devices = {'K80','X6','ACE5'}; end
if nargin < 2 || isempty(epoch_limit); epoch_limit = Inf; end
if nargin < 3 || isempty(test_model); test_model = 'wls_residual'; end
if nargin < 4; experiment = struct(); end
if ~isfield(experiment,'capture_stride'); experiment.capture_stride = 0; end
if ~isfield(experiment,'output_group'); experiment.output_group = 'PPP_RAIM_MONITOR_STAGE2_20260930'; end
assert(~isempty(regexp(experiment.output_group,'^[A-Za-z0-9_]+$','once')));
if ischar(devices) || isstring(devices); devices = cellstr(devices); end
assert(any(strcmpi(test_model,{'wls_residual','innovation'})), ...
    'test_model must be wls_residual or innovation.');

% Keep the runner usable from a fresh MATLAB -batch session started in WORK.
% A normal raPPPid GUI launch has already added this tree.
if exist('PPP_main','file') ~= 2
    addpath(genpath(Path.CODE));
end

global STOP_CALC
STOP_CALC = 0;
root = fullfile(Path.RESULTS,experiment.output_group);
if ~exist(root,'dir'); mkdir(root); end

specs = winningSpecs();
rows = {};
for i = 1:numel(specs)
    if ~any(strcmpi(specs(i).id,devices)); continue; end
    assert(isfile(specs(i).settings),'Winning settings not found: %s',specs(i).settings);
    S = load(specs(i).settings,'settings'); s = S.settings;
    assert(isfile(s.INPUT.file_obs),'Winning observation input not found: %s',s.INPUT.file_obs);

    s.INPUT.bool_batch = true;
    s.INPUT.bool_parfor = true;
    s.PROC.name = sprintf('%s/%s',experiment.output_group,specs(i).id);
    s.PROC.raim = struct('enable',true,'mode','monitor_only', ...
        'test_model',char(test_model),'pfa_global',1e-3,'min_redundancy',1);
    s.PROC.raim.capture_stride = experiment.capture_stride;
    s.PROC.raim.implementation_version = 'whitened_v2_20261005';
    if isfinite(epoch_limit)
        n_end = min(s.PROC.epochs(2), ...
            s.PROC.epochs(1) + max(1,round(epoch_limit)) - 1);
        s.PROC.epochs = [s.PROC.epochs(1) n_end];
        % PPP_main derives epochs again from timeFrame, so both fields must
        % describe the same epoch-index interval for a bounded smoke run.
        s.PROC.timeFrame = s.PROC.epochs;
        s.PROC.timeFrameFrom = num2str(s.PROC.epochs(1));
        s.PROC.timeFrameTo = num2str(s.PROC.epochs(2));
        s.PROC.timeSpan_format_epochs = true;
        s.PROC.timeSpan_format_time = false;
        s.PROC.timeSpan_format_SOD = false;
        s.PROC.timeSpan_format_HOD = false;
    end

    fprintf('RAIM_STAGE2_START %s epochs=%d:%d\nInput: %s\n', ...
        specs(i).id,s.PROC.epochs(1),s.PROC.epochs(2),s.INPUT.file_obs);
    logtext = evalc('out = PPP_main(s);');
    fid = fopen(fullfile(out.PROC.output_dir,'processing_console.txt'),'w');
    if fid >= 0; fwrite(fid,logtext); fclose(fid); end

    result_file = fullfile(out.PROC.output_dir,'data4plot.mat');
    assert(isfile(result_file),'RAIM stage-2 result missing: %s',result_file);
    stats = summarizeRaim(result_file);
    rows(end+1,:) = {specs(i).id,stats.epochs,stats.available_pct, ... %#ok<AGROW>
        stats.fail_pct_available,stats.insufficient_pct,stats.median_stat_ratio, ...
        stats.p95_max_w,stats.unique_candidate_sats,char(out.PROC.output_dir), ...
        s.INPUT.file_obs,char(test_model),s.PROC.raim.implementation_version};
    fprintf(['RAIM_STAGE2_DONE %s available=%.2f%% fail=%.2f%% ' ...
        'insufficient=%.2f%% median_D_T=%.3f p95_max_w=%.3f\n'], ...
        specs(i).id,stats.available_pct,stats.fail_pct_available, ...
        stats.insufficient_pct,stats.median_stat_ratio,stats.p95_max_w);
end

manifest = cell2table(rows,'VariableNames',{'device','epochs', ...
    'raim_available_pct','global_fail_pct_available','insufficient_redundancy_pct', ...
    'median_statistic_threshold_ratio','p95_max_standardized_residual', ...
    'unique_candidate_satellites','output_dir','input_obs','test_model','implementation_version'});
stamp = datestr(now,'yyyymmdd_HHMMSS');
writetable(manifest,fullfile(root,['manifest_' stamp '.csv']));
save(fullfile(root,['manifest_' stamp '.mat']),'manifest');
disp(manifest);
end


function specs = winningSpecs()
base = '../RESULTS/';
specs(1) = struct('id','K80','settings',[base ...
    'PPP_K80_QUALITY_GATED_DOPPLER_MP_20260924/' ...
    'GNSS00GEO_R_20261160237_60M_01S_MO-doppler predicted-multipath corrected/' ...
    'quality_gated_doppler_mp_1p0x_24-Sep-2026_17h08m22s/settings.mat']);
specs(2) = struct('id','X6','settings',[base ...
    'PPP_CORRECTED_BEST_20260906/' ...
    'GNSS00GEO_R_20261160237_60M_01S_MO-multipath corrected/' ...
    'X6_06-Sep-2026_20h53m33s/settings.mat']);
specs(3) = struct('id','ACE5','settings',[base ...
    'PPP_CORRECTED_BEST_20260906/' ...
    'GNSS00GEO_R_20261160237_59M_01S_MO-multipath corrected/' ...
    'ACE5_06-Sep-2026_20h59m57s/settings.mat']);
end


function stats = summarizeRaim(file)
S = load(file,'storeData'); D = S.storeData;
n = numel(D.gpstime);
available = logical(D.raim_available(:));
failed = available & ~logical(D.raim_pass(:));
insufficient = D.raim_status_code(:) == 3;
ratio = D.raim_statistic(:) ./ D.raim_threshold(:);
ratio = ratio(available & isfinite(ratio));
max_w = D.raim_max_standardized_residual(:);
max_w = max_w(available & isfinite(max_w));
candidates = D.raim_candidate_satellite(failed);
candidates = unique(candidates(isfinite(candidates)));

stats.epochs = n;
stats.available_pct = 100*mean(available);
stats.fail_pct_available = 100*sum(failed)/max(1,sum(available));
stats.insufficient_pct = 100*mean(insufficient);
stats.median_stat_ratio = median(ratio,'omitnan');
stats.p95_max_w = prctile(max_w,95);
stats.unique_candidate_sats = numel(candidates);
end
