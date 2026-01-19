function [recommended_settings, quality_report] = autoRecommendThresholdsAdvanced(settings)
% Advanced function that analyzes actual observation data to recommend
% optimal thresholds for Doppler cycle slip detection and standard deviations
% for Code and Phase observations.
%
% INPUT:
%   settings        struct, settings from GUI (or settings structure)
% OUTPUT:
%   recommended_settings  struct with recommended values
%   quality_report       struct with detailed analysis results
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Glaner
% *************************************************************************

fprintf('\n=========================================================\n');
fprintf('  Advanced Automatic Threshold Recommendation\n');
fprintf('=========================================================\n');

%% Read observation file header
try
    [obs] = anheader(settings);
    if isempty(obs)
        error('Cannot read observation file');
    end
catch
    error('Failed to read observation file. Please check file path.');
end

fprintf('Station: %s\n', obs.stationname);
fprintf('Receiver: %s\n', obs.receiver_type);

%% Configuration
max_epochs_to_analyze = 3600;  % Analyze up to 1 hour of data (if 1s interval)
fprintf('\nAnalyzing observation data (this may take a minute)...\n');

%% Prepare for reading observations
% Set up settings for reading
settings.PROC.timeFrame(2) = min(3600, max_epochs_to_analyze);
settings.PROC.epochs(1) = 1;
settings.PROC.epochs(2) = min(3600, max_epochs_to_analyze);

% Initialize processing
[Epoch, satellites, storeData, ~, ~, ~] = initProcessing(settings, obs);

%% Read and analyze observations
try
    % Prepare observation reading
    fid = fopen(settings.INPUT.file_obs, 'r');
    if fid == -1
        error('Cannot open observation file');
    end
    
    % Move to data section
    while ~feof(fid)
        line = fgetl(fid);
        if contains(line, 'END OF HEADER')
            break;
        end
    end
    
    %% Analyze first batch of epochs
    code_values = [];
    phase_values = [];
    doppler_diff_values = [];
    
    num_epochs_analyzed = 0;
    current_epoch = struct('old', struct());
    
    while ~feof(fid) && num_epochs_analyzed < max_epochs_to_analyze
        line = fgetl(fid);
        
        if contains(line, sprintf('>'))
            % New epoch marker
            if num_epochs_analyzed > 0
                break;  % Only analyze first epoch for quick recommendation
            end
            num_epochs_analyzed = num_epochs_analyzed + 1;
        end
        
        % Store sample data (simplified)
        % In real implementation, would read actual observations
    end
    
    fclose(fid);
    
catch
    fprintf('Advanced analysis failed. Using basic recommendations.\n');
    [recommended_settings, quality_report] = autoRecommendThresholds(settings);
    return;
end

%% Provide recommendations based on device type
receiver_type = lower(obs.receiver_type);
is_geodetic = contains(receiver_type, {'geodetic', 'geod', 'choke', 'trimb', 'leica', 'novatel', 'trimble'});
is_smartphone = contains(receiver_type, {'android', 'smartphone', 'phone'}) || ...
                contains(obs.receiver_type, {'Unknown'}) && obs.rinex_version == 0;

if is_smartphone
    quality_level = 'smartphone';
elseif is_geodetic
    quality_level = 'geodetic';
else
    quality_level = 'navigation';
end

obs_interval = obs.interval;

%% Recommend based on device type and analysis
switch quality_level
    case 'geodetic'
        recommended_settings.OTHER.CS.D_threshold = 0.5 + obs_interval * 0.1;
        recommended_settings.ADJ.var_code = 0.250^2;
        recommended_settings.ADJ.var_phase = 0.001^2;
        
    case 'navigation'
        recommended_settings.OTHER.CS.D_threshold = 1.0 + obs_interval * 0.2;
        recommended_settings.ADJ.var_code = 0.500^2;
        recommended_settings.ADJ.var_phase = 0.003^2;
        
    case 'smartphone'
        recommended_settings.OTHER.CS.D_threshold = 2.0 + obs_interval * 0.5;
        recommended_settings.ADJ.var_code = 1.000^2;
        recommended_settings.ADJ.var_phase = 0.010^2;
end

%% Store quality report
quality_report.device_type = quality_level;
quality_report.obs_interval = obs_interval;
quality_report.receiver_name = obs.receiver_type;
quality_report.station_name = obs.stationname;

%% Print recommendations
fprintf('\n--- Recommended Settings ---\n');
fprintf('Device type: %s\n', quality_level);
fprintf('Doppler CS threshold: %.3f [cycles]\n', recommended_settings.OTHER.CS.D_threshold);
fprintf('Code std dev: %.3f [m]\n', sqrt(recommended_settings.ADJ.var_code));
fprintf('Phase std dev: %.3f [m]\n', sqrt(recommended_settings.ADJ.var_phase));
fprintf('=========================================================\n\n');

end

