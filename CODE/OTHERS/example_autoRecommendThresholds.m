% Example: How to use autoRecommendThresholds
%
% This script demonstrates how to automatically get threshold recommendations
% for a RINEX observation file.
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Glaner
% *************************************************************************

clear; clc;

fprintf('=========================================================\n');
fprintf('  Example: Auto-Recommend Thresholds\n');
fprintf('=========================================================\n\n');

%% Method 1: Use from command window with current settings
% Load current settings from workspace or parameter file
try
    % Try to use current settings if available
    if exist('settings', 'var')
        fprintf('Using current settings from workspace.\n');
        obs_settings = settings;
    else
        % Load from parameter file
        param_file = 'PARAMETERS/default.mat';
        fprintf('Loading settings from: %s\n', param_file);
        load(param_file, 'parameters');
        obs_settings = parameters;
    end
catch
    error('Please load settings first. Either run GUI or load a parameter file.');
end

%% Method 2: Specify observation file manually
% Uncomment and modify if needed:
% obs_settings = struct();
% obs_settings.INPUT.file_obs = 'DATA/OBS/your_obs_file.obs';
% obs_settings.INPUT.use_GPS = true;
% obs_settings.INPUT.use_GLO = false;
% obs_settings.INPUT.use_GAL = false;
% obs_settings.INPUT.use_BDS = false;
% obs_settings.INPUT.gps_freq = {'1F', '2W', '5X'};

%% Get automatic recommendations
fprintf('\nGetting automatic recommendations...\n');
try
    [recommended_settings, quality_report] = autoRecommendThresholds(obs_settings);
    
    %% Display results
    fprintf('\n=========================================================\n');
    fprintf('  RECOMMENDATIONS SUMMARY\n');
    fprintf('=========================================================\n');
    fprintf('Device Type: %s\n', quality_report.device_type);
    fprintf('Observation Interval: %.1f [s]\n', quality_report.obs_interval);
    fprintf('\n--- Recommended Thresholds ---\n');
    fprintf('Doppler CS Threshold: %.3f [cycles]\n', ...
        recommended_settings.OTHER.CS.D_threshold);
    fprintf('Code Standard Deviation: %.3f [m]\n', ...
        sqrt(recommended_settings.ADJ.var_code));
    fprintf('Phase Standard Deviation: %.3f [m]\n', ...
        sqrt(recommended_settings.ADJ.var_phase));
    fprintf('=========================================================\n');
    
    %% Apply recommendations (optional)
    fprintf('\nTo apply these recommendations:\n');
    fprintf('Option 1: Copy values to GUI manually\n');
    fprintf('Option 2: Apply programmatically as shown below:\n\n');
    
    % Show code to apply
    fprintf('%% Apply recommendations to your settings:\n');
    fprintf('settings.OTHER.CS.D_threshold = %.3f;\n', ...
        recommended_settings.OTHER.CS.D_threshold);
    fprintf('settings.ADJ.var_code = %.6f;\n', ...
        recommended_settings.ADJ.var_code);
    fprintf('settings.ADJ.var_phase = %.6f;\n', ...
        recommended_settings.ADJ.var_phase);
    
    %% Optional: Uncomment to apply directly
    % settings.OTHER.CS.D_threshold = recommended_settings.OTHER.CS.D_threshold;
    % settings.ADJ.var_code = recommended_settings.ADJ.var_code;
    % settings.ADJ.var_phase = recommended_settings.ADJ.var_phase;
    % fprintf('\nSettings have been updated in workspace.\n');
    
catch ME
    fprintf('Error getting recommendations: %s\n', ME.message);
    fprintf('\nPossible solutions:\n');
    fprintf('1. Check that observation file path is correct\n');
    fprintf('2. Ensure observation file is valid RINEX format\n');
    fprintf('3. Check that all required settings are configured\n');
end

fprintf('\n\nDone!\n');

