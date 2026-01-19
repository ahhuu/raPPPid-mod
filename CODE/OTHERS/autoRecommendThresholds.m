function [recommended_settings, quality_report] = autoRecommendThresholds(settings)
% This function automatically recommends thresholds for Doppler cycle slip
% detection and standard deviations for Code and Phase observations based on
% quick analysis of the observation file.
%
% INPUT:
%   settings        struct, settings from GUI (or settings structure)
% OUTPUT:
%   recommended_settings  struct with recommended values
%   quality_report       struct with analysis results
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Glaner
% *************************************************************************

fprintf('\n=========================================================\n');
fprintf('  Automatic Threshold Recommendation\n');
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

%% Quick analysis of a subset of observations
fprintf('\nPerforming quick analysis...\n');

% Initialize recommended values with defaults
recommended_settings = struct();
quality_report = struct();

% Get observation interval
obs_interval = obs.interval;  % [s]
fprintf('Observation interval: %.1f [s]\n', obs_interval);

%% Determine receiver type and recommend accordingly
receiver_type = lower(obs.receiver_type);
is_geodetic = contains(receiver_type, {'geodetic', 'geod', 'choke', 'trimb', 'leica', 'novatel', 'trimble'});
is_smartphone = contains(receiver_type, {'android', 'smartphone', 'phone'}) || ...
                contains(obs.receiver_type, {'Unknown'}) && obs.rinex_version == 0;

if is_smartphone
    quality_level = 'smartphone';
    fprintf('Detected device type: Smartphone\n');
elseif is_geodetic
    quality_level = 'geodetic';
    fprintf('Detected device type: Geodetic receiver\n');
else
    quality_level = 'navigation';
    fprintf('Detected device type: Navigation grade\n');
end

%% Recommend Doppler threshold
% Base recommendation on observation interval
switch quality_level
    case 'geodetic'
        % High-quality receivers with stable Doppler measurements
        if obs_interval <= 1
            doppler_thresh = 0.5;
        elseif obs_interval <= 5
            doppler_thresh = 1.0;
        elseif obs_interval <= 30
            doppler_thresh = 2.0;
        else
            doppler_thresh = 3.0;
        end
        
    case 'navigation'
        % Navigation-grade receivers
        if obs_interval <= 1
            doppler_thresh = 1.0;
        elseif obs_interval <= 5
            doppler_thresh = 2.0;
        elseif obs_interval <= 30
            doppler_thresh = 3.0;
        else
            doppler_thresh = 5.0;
        end
        
    case 'smartphone'
        % Smartphones with less stable measurements
        if obs_interval <= 1
            doppler_thresh = 2.0;
        elseif obs_interval <= 5
            doppler_thresh = 3.0;
        elseif obs_interval <= 30
            doppler_thresh = 5.0;
        else
            doppler_thresh = 10.0;
        end
end

recommended_settings.OTHER.CS.D_threshold = doppler_thresh;

fprintf('  Doppler threshold: %.2f [cycles]\n', doppler_thresh);

%% Recommend Code standard deviation
switch quality_level
    case 'geodetic'
        % Very precise geodetic receivers
        code_std = 0.250;  % [m]
        phase_std = 0.001; % [m]
        
    case 'navigation'
        % Standard navigation-grade receivers
        code_std = 0.500;  % [m]
        phase_std = 0.003; % [m]
        
    case 'smartphone'
        % Smartphones with larger noise
        code_std = 1.000;  % [m]
        phase_std = 0.010; % [m]
end

recommended_settings.ADJ.var_code = code_std^2;
recommended_settings.ADJ.var_phase = phase_std^2;

fprintf('  Code std dev: %.3f [m]\n', code_std);
fprintf('  Phase std dev: %.3f [m]\n', phase_std);

%% Store quality report
quality_report.device_type = quality_level;
quality_report.obs_interval = obs_interval;
quality_report.receiver_name = obs.receiver_type;
quality_report.station_name = obs.stationname;

%% Print summary
fprintf('\n--- Recommended Settings ---\n');
fprintf('Doppler CS threshold: %.3f [cycles]\n', doppler_thresh);
fprintf('Code std dev: %.3f [m]\n', code_std);
fprintf('Phase std dev: %.3f [m]\n', phase_std);
fprintf('=========================================================\n\n');

%% Option to apply recommendations
fprintf('To apply these recommendations:\n');
fprintf('  - In GUI: Models → Other Corrections → Doppler Shift Threshold\n');
fprintf('  - In GUI: Estimation → Weighting → Code/Phase Std Dev\n');
fprintf('\nOr programmatically:\n');
fprintf('  settings.OTHER.CS.D_threshold = %.3f;\n', doppler_thresh);
fprintf('  settings.ADJ.var_code = %.6f;\n', code_std^2);
fprintf('  settings.ADJ.var_phase = %.6f;\n', phase_std^2);

end

