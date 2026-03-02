function calibrate_bds23_isb(varargin)
% calibrate_bds23_isb  Extract calibrated BDS-2/BDS-3 ISB from processing results
%
% This script extracts the ISB value from one or more previous raPPPid
% processing results (which used 'free' ISB estimation) and writes the
% calibrated value into settings.mat for subsequent 'constrained' mode runs.
%
% USAGE:
%   calibrate_bds23_isb                  % interactive: select result folder(s) via dialog
%   calibrate_bds23_isb(result_dir)      % single result directory path
%   calibrate_bds23_isb({dir1, dir2})    % cell array of directories
%
% WORKFLOW:
%   1. Run raPPPid with ISB enabled in 'free' mode (default) on known-position data
%   2. Run this script, pointing to the result folder(s)
%   3. The script extracts the converged ISB median, prints statistics
%   4. Optionally writes the calibrated ISB into WORK/settings.mat
%
% The calibrated ISB can then be used in 'constrained' mode or 'fixed' mode:
%   settings.BIASES.bds23_isb_mode          = 'constrained';
%   settings.BIASES.bds23_isb_prior_m       = <calibrated value>;
%   settings.BIASES.bds23_isb_prior_sigma_m = 3.0;  % adjust as needed
%   settings.BIASES.bds23_isb_mode          = 'fixed';
%   settings.BIASES.bds23_isb_fixed_m       = <calibrated median value>;
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

c = 299792458;  % speed of light [m/s]
m2ns = 1e9 / c; % meters to nanoseconds conversion

%% Parse input
if nargin == 0
    % Interactive: let user select folder(s)
    result_dirs = {};
    while true
        folder = uigetdir(pwd, 'Select a result directory (Cancel to finish)');
        if folder == 0
            break;
        end
        result_dirs{end+1} = folder; %#ok<AGROW>
    end
    if isempty(result_dirs)
        fprintf('No result directories selected. Aborting.\n');
        return;
    end
elseif iscell(varargin{1})
    result_dirs = varargin{1};
else
    result_dirs = {varargin{1}};
end

%% Extract ISB from each result
all_isb_m = [];   % collected ISB values in meters
all_isb_ns = [];  % collected ISB values in nanoseconds
skip_epochs = 300; % skip first N epochs for convergence

fprintf('\n=== BDS-2/BDS-3 ISB Calibration ===\n\n');

for i = 1:numel(result_dirs)
    result_dir = result_dirs{i};
    data_file = fullfile(result_dir, 'data4plot.mat');
    
    if ~exist(data_file, 'file')
        fprintf('WARNING: %s not found, skipping.\n', data_file);
        continue;
    end
    
    % Load storeData
    loaded = load(data_file);
    if ~isfield(loaded, 'storeData')
        fprintf('WARNING: storeData not found in %s, skipping.\n', data_file);
        continue;
    end
    storeData = loaded.storeData;
    
    % Check if ISB was estimated (param column 20 exists and is non-zero)
    if size(storeData.param, 2) < 20
        fprintf('WARNING: Only %d params in %s (need 20 for ISB), skipping.\n', ...
            size(storeData.param, 2), result_dir);
        continue;
    end
    
    isb_ts = storeData.param(:, 20);  % ISB time series [m]
    
    % Remove zero epochs (not processed or ISB disabled)
    valid = isb_ts ~= 0 & ~isnan(isb_ts);
    isb_valid = isb_ts(valid);
    n_valid = numel(isb_valid);
    
    if n_valid < skip_epochs + 100
        fprintf('WARNING: Only %d valid ISB epochs in %s (need >%d), skipping.\n', ...
            n_valid, result_dir, skip_epochs + 100);
        continue;
    end
    
    % Skip convergence period
    isb_converged = isb_valid((skip_epochs+1):end);
    
    isb_median_m = median(isb_converged, 'omitnan');
    isb_mean_m   = mean(isb_converged, 'omitnan');
    isb_std_m    = std(isb_converged, 'omitnan');
    
    fprintf('Result: %s\n', result_dir);
    fprintf('  Valid epochs: %d (used %d after skip %d)\n', n_valid, numel(isb_converged), skip_epochs);
    fprintf('  ISB median:   %+.4f m  (%+.2f ns)\n', isb_median_m, isb_median_m * m2ns);
    fprintf('  ISB mean:     %+.4f m  (%+.2f ns)\n', isb_mean_m, isb_mean_m * m2ns);
    fprintf('  ISB std:       %.4f m  ( %.2f ns)\n', isb_std_m, isb_std_m * m2ns);
    fprintf('\n');
    
    all_isb_m  = [all_isb_m;  isb_converged]; %#ok<AGROW>
    all_isb_ns = [all_isb_ns; isb_converged * m2ns]; %#ok<AGROW>
end

if isempty(all_isb_m)
    fprintf('ERROR: No valid ISB data extracted. Cannot calibrate.\n');
    return;
end

%% Combined statistics
combined_median_m  = median(all_isb_m, 'omitnan');
combined_mean_m    = mean(all_isb_m, 'omitnan');
combined_std_m     = std(all_isb_m, 'omitnan');

fprintf('========================================\n');
fprintf('Combined ISB calibration (%d total epochs from %d result(s)):\n', ...
    numel(all_isb_m), numel(result_dirs));
fprintf('  Median: %+.4f m  (%+.2f ns)\n', combined_median_m, combined_median_m * m2ns);
fprintf('  Mean:   %+.4f m  (%+.2f ns)\n', combined_mean_m, combined_mean_m * m2ns);
fprintf('  Std:     %.4f m  ( %.2f ns)\n', combined_std_m, combined_std_m * m2ns);
fprintf('========================================\n\n');

%% Recommended settings
% Use median as prior, and max(std, 1.0) as sigma for some safety margin
recommended_prior_m = combined_median_m;
recommended_sigma_m = max(combined_std_m * 3, 1.0);  % 3-sigma or at least 1m

fprintf('Recommended settings:\n');
fprintf('  Prior[m] = %.4f   (%+.2f ns)\n', recommended_prior_m, recommended_prior_m * m2ns);
fprintf('  Sigma[m] = %.2f\n\n', recommended_sigma_m);
fprintf('  Fixed[m] = %.4f   (%+.2f ns)\n\n', recommended_prior_m, recommended_prior_m * m2ns);
fprintf('How to use:\n');
fprintf('  1. In GUI: check BDS-2/3 ISB, select "constrained" in dropdown\n');
fprintf('  2. Enter the above Prior[m] and Sigma[m] values\n');
fprintf('  3. Or select "fixed" and enter Fixed[m] = median value\n');
fprintf('  4. Click RUN\n\n');

%% Plot ISB time series
figure('Name', 'BDS-2/BDS-3 ISB Calibration', 'NumberTitle', 'off');

subplot(2,1,1);
plot(all_isb_ns, '.', 'MarkerSize', 2);
hold on;
yline(combined_median_m * m2ns, 'r-', 'LineWidth', 2);
yline((combined_median_m + combined_std_m) * m2ns, 'r--');
yline((combined_median_m - combined_std_m) * m2ns, 'r--');
xlabel('Epoch (after convergence skip)');
ylabel('ISB [ns]');
title(sprintf('BDS-2/BDS-3 ISB: median = %.2f ns, std = %.2f ns', ...
    combined_median_m * m2ns, combined_std_m * m2ns));
grid on;

subplot(2,1,2);
histogram(all_isb_ns, 50, 'Normalization', 'pdf');
hold on;
xline(combined_median_m * m2ns, 'r-', 'LineWidth', 2);
xlabel('ISB [ns]');
ylabel('Probability density');
title('ISB Distribution');
grid on;

fprintf('\nCalibration complete.\n');
end
