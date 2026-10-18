function [summary, candidates] = analyzeRaimStage2Calibration20260930()
%ANALYZERAIMSTAGE2CALIBRATION20260930 Summarize full-run RAIM diagnostics.
%   The output is descriptive calibration evidence only. It does not tune
%   settings, exclude observations, or claim that tree-shaded data are a
%   fault-free reference distribution.

root = '../RESULTS/PPP_RAIM_MONITOR_STAGE2_20260930';
specs = { ...
    'K80',  3600, '*K80_*'; ...
    'X6',   3600, '*X6_*'; ...
    'ACE5', 2272, '*ACE5_*'};

summary_rows = cell(0,22);
candidate_rows = cell(0,5);
for i = 1:size(specs,1)
    device = specs{i,1};
    expected_epochs = specs{i,2};
    result_file = findLatestFullRun(root,specs{i,3},expected_epochs);
    S = load(result_file,'storeData'); D = S.storeData;

    available = logical(D.raim_available(:));
    statistic = double(D.raim_statistic(:));
    threshold = double(D.raim_threshold(:));
    dof = double(D.raim_dof(:));
    use = available & isfinite(statistic) & isfinite(threshold) & ...
        threshold > 0 & dof > 0;
    ratio = statistic(use) ./ threshold(use);
    unit_variance = statistic(use) ./ dof(use);
    max_w = double(D.raim_max_standardized_residual(use));

    obs_mask = D.raim_observed_freq;
    residual = abs(double(D.raim_residual_m_freq(obs_mask)));
    residual = residual(isfinite(residual));

    q_ratio = pct(ratio,[50 90 95 99 99.9]);
    q_w = pct(max_w,[50 95 99]);
    q_res = pct(residual,[50 95 99]);
    sigma_inflation = sqrt(median(unit_variance,'omitnan'));
    % Because scaling observation sigma by s divides the global statistic
    % by s^2, these are descriptive scales for selected empirical alarm
    % rates in this same shaded dataset. They are not nominal Pfa proof.
    sigma_for_alarm_10pct = sqrt(q_ratio(2));
    sigma_for_alarm_5pct = sqrt(q_ratio(3));
    sigma_for_alarm_1pct = sqrt(q_ratio(4));
    sigma_for_alarm_0p1pct = sqrt(q_ratio(5));

    summary_rows(end+1,:) = {device,numel(D.gpstime),100*mean(available), ... %#ok<AGROW>
        100*mean(available & ~logical(D.raim_pass(:))), ...
        sigma_inflation,q_ratio(1),q_ratio(2),q_ratio(3),q_ratio(4),q_ratio(5), ...
        q_w(1),q_w(2),q_w(3),q_res(1),q_res(2),q_res(3), ...
        sigma_for_alarm_10pct,sigma_for_alarm_5pct, ...
        sigma_for_alarm_1pct,sigma_for_alarm_0p1pct, ...
        numel(residual),result_file};

    failed = available & ~logical(D.raim_pass(:));
    sat = double(D.raim_candidate_satellite(failed));
    freq = double(D.raim_candidate_frequency(failed));
    valid_candidate = isfinite(sat) & sat > 0 & freq > 0;
    sat = sat(valid_candidate); freq = freq(valid_candidate);
    if ~isempty(sat)
        [groups,~,group_id] = unique([sat freq],'rows');
        counts = accumarray(group_id,1);
        [counts,order] = sort(counts,'descend');
        groups = groups(order,:);
        take = 1:min(10,numel(counts));
        for j = take
            candidate_rows(end+1,:) = {device,groups(j,1),groups(j,2), ... %#ok<AGROW>
                counts(j),100*counts(j)/sum(counts)};
        end
    end
end

summary = cell2table(summary_rows,'VariableNames',{ ...
    'device','epochs','available_pct','global_fail_pct_all_epochs', ...
    'robust_sigma_inflation_candidate','stat_threshold_p50', ...
    'stat_threshold_p90','stat_threshold_p95','stat_threshold_p99', ...
    'stat_threshold_p999','max_standardized_p50','max_standardized_p95', ...
    'max_standardized_p99','abs_code_residual_m_p50', ...
    'abs_code_residual_m_p95','abs_code_residual_m_p99', ...
    'empirical_sigma_scale_for_10pct_alarm', ...
    'empirical_sigma_scale_for_5pct_alarm', ...
    'empirical_sigma_scale_for_1pct_alarm', ...
    'empirical_sigma_scale_for_0p1pct_alarm', ...
    'observation_count','result_file'});
candidates = cell2table(candidate_rows,'VariableNames',{ ...
    'device','satellite','frequency','candidate_count','candidate_pct'});

stamp = datestr(now,'yyyymmdd_HHMMSS');
writetable(summary,fullfile(root,['calibration_summary_' stamp '.csv']));
writetable(candidates,fullfile(root,['candidate_ranking_' stamp '.csv']));
save(fullfile(root,['calibration_' stamp '.mat']),'summary','candidates');
disp(summary(:,1:20));
disp(candidates);
end


function result_file = findLatestFullRun(root,pattern,expected_epochs)
files = dir(fullfile(root,'**',pattern,'data4plot.mat'));
assert(~isempty(files),'No RAIM result found for pattern %s.',pattern);
[~,order] = sort([files.datenum],'descend');
for k = order
    candidate = fullfile(files(k).folder,files(k).name);
    vars = whos('-file',candidate);
    if ~any(strcmp({vars.name},'storeData')); continue; end
    S = load(candidate,'storeData','settings');
    if ~isfield(S,'settings') || ~isfield(S.settings.PROC,'raim'); continue; end
    cfg = S.settings.PROC.raim;
    if isfield(cfg,'test_model') && ~strcmpi(cfg.test_model,'wls_residual'); continue; end
    if numel(S.storeData.gpstime) == expected_epochs
        result_file = candidate;
        return;
    end
end
error('No full RAIM run with %d epochs found for %s.',expected_epochs,pattern);
end


function values = pct(data,percentages)
data = data(isfinite(data));
if isempty(data)
    values = NaN(size(percentages));
else
    values = prctile(data,percentages);
end
end
