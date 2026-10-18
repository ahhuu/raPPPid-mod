function createRaimOutput(storeData, output_dir)
%CREATERAIMOUTPUT Export epoch and observation-level RAIM diagnostics.

n = numel(storeData.gpstime);
epoch = (1:n)';
status = strings(n,1);
for i = 1:n
    status(i) = statusText(storeData.raim_status_code(i));
end

summary = table(epoch, storeData.gpstime(:), status, ...
    logical(storeData.raim_available(:)), logical(storeData.raim_pass(:)), ...
    double(storeData.raim_dof(:)), double(storeData.raim_n_observations(:)), ...
    double(storeData.raim_n_parameters(:)), storeData.raim_statistic(:), ...
    storeData.raim_threshold(:), storeData.raim_pfa_global(:), ...
    storeData.raim_max_standardized_residual(:), ...
    storeData.raim_candidate_satellite(:), ...
    double(storeData.raim_candidate_frequency(:)), ...
    'VariableNames', {'epoch','gps_time_sow','status','available','pass', ...
    'dof','n_observations','n_parameters','statistic','threshold', ...
    'pfa_global','max_standardized_residual','candidate_satellite', ...
    'candidate_frequency'});
if isfield(storeData,'raim_action_code')
    summary.action_code=double(storeData.raim_action_code(:)); % 0=none,1=code exclusion,2=code downweight
    summary.action_satellite=storeData.raim_action_satellite(:);
    summary.action_frequency=double(storeData.raim_action_frequency(:));
    summary.action_post_ratio=storeData.raim_action_post_ratio(:);
    summary.action_geometry_ratio=storeData.raim_action_geometry_ratio(:);
end
writetable(summary, fullfile(output_dir,'raim_epoch_summary.csv'));

[q, sat, freq] = ind2sub(size(storeData.raim_observed_freq), ...
    find(storeData.raim_observed_freq));
if isempty(q)
    detail = table([],[],[],[],[],[], ...
        'VariableNames', {'epoch','gps_time_sow','satellite','frequency', ...
        'residual_m','standardized_residual'});
else
    idx = sub2ind(size(storeData.raim_observed_freq), q, sat, freq);
    detail = table(q, storeData.gpstime(q), sat, freq, ...
        double(storeData.raim_residual_m_freq(idx)), ...
        double(storeData.raim_standardized_residual_freq(idx)), ...
        'VariableNames', {'epoch','gps_time_sow','satellite','frequency', ...
        'residual_m','standardized_residual'});
end
writetable(detail, fullfile(output_dir,'raim_observation_details.csv'));
end


function value = statusText(code)
switch double(code)
    case 1; value = "pass";
    case 2; value = "fault_detected";
    case 3; value = "insufficient_redundancy";
    case 4; value = "no_code_rows";
    case 5; value = "missing_adjustment_data";
    case 6; value = "unsupported_mode";
    case 7; value = "missing_state_covariance";
    case 8; value = "unsupported_test_model";
    case 9; value = "invalid_covariance";
    case 10; value = "ill_conditioned_covariance";
    otherwise; value = "disabled";
end
end
