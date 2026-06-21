function [param, param_sigma, float, omc, A, Q_l] = KalmanFilterIGGIII(omc, A, x_pred, Q_x_pred, Q_l, settings)
% Calculate robust PPP solution with IGGIII Kalman Filter scheme 
%
% INPUT: 
%   omc             vector, observed minus computed (innovation)
%   A               matrix, Design Matrix / Observation Matrix
%   x_pred          vector, predicted parameters
%   Q_x_pred        matrix, predicted covariance matrix of parameters
%   Q_l             matrix, covariance matrix of observations
%   settings        struct, raPPPid settings to read IGGIII thresholds
% OUTPUT:
%   param           parameter vector after Kalman Filtering 
%   param_sigma     covariance matrix after Kalman Filtering
%   float           boolean, valid float solution?
%   omc             updated innovation vector (with implicit exclusions applied)
%   A               updated design matrix (with implicit exclusions applied)
%   Q_l             updated observation covariance matrix (with robust weighting applied)
%
% Note: prediction (x_pred, Q_x_pred) was calculated in adjPrep_ZD/_iono/_DCM.m
% *************************************************************************

%% 1. Preparations
% Check for NaNs in observed-minus-computed
idx_nan = isnan(omc);
omc(idx_nan) = 0;
A(idx_nan, :) = 0;

% Identify valid observations (non-NaN and non-zero rows in A matrix)
valid_idx = ~idx_nan & (sum(abs(A), 2) > 0);

% Identity Matrix with the size of the Design Matrix / Observation Matrix
I = eye(size(A,2));


%% 2. Calculate Standardized Innovations (Standardized Residuals)
% Innovation Covariance Matrix: Q_d = Q_l + A * Q_x_pred * A'
Q_d = Q_l + A * Q_x_pred * A';

diag_Qd = diag(Q_d);
% Numerical protection: prevent division by zero in case of singular covariances
diag_Qd(diag_Qd < 1e-12) = 1e-12;

% Calculate standardized residuals for valid observations
v_std = zeros(size(omc));
v_std(valid_idx) = omc(valid_idx) ./ sqrt(diag_Qd(valid_idx));


%% 3. Calculate IGGIII Equivalent Weight Factor
% Set default IGGIII thresholds
k0 = 2.0;
k1 = 4.0;

% Check if custom thresholds are defined in settings
if isfield(settings, 'ADJ') && isfield(settings.ADJ, 'filter')
    if isfield(settings.ADJ.filter, 'k0') && ~isempty(settings.ADJ.filter.k0)
        k0 = settings.ADJ.filter.k0;
    end
    if isfield(settings.ADJ.filter, 'k1') && ~isempty(settings.ADJ.filter.k1)
        k1 = settings.ADJ.filter.k1;
    end
end

gamma = ones(size(omc));
exclude_mask = false(size(omc));

% Check for soft weighting configuration
soft_exclusion = false;
soft_factor = 1e-7;
if isfield(settings, 'ADJ') && isfield(settings.ADJ, 'filter')
    if isfield(settings.ADJ.filter, 'soft_exclusion')
        soft_exclusion = settings.ADJ.filter.soft_exclusion;
    end
    if isfield(settings.ADJ.filter, 'soft_factor')
        soft_factor = settings.ADJ.filter.soft_factor;
    end
end

persistent last_name;
if isempty(last_name) || ~strcmp(last_name, settings.PROC.name)
    fprintf('=== DEBUG [%s]: soft_exclusion = %d, soft_factor = %e, Doppler = %d, TDCP_thresh = %.2f ===\n', ...
        settings.PROC.name, soft_exclusion, soft_factor, settings.OTHER.CS.Doppler, settings.OTHER.CS.TDCP_threshold);
    last_name = settings.PROC.name;
end

persistent has_printed_diag;
if isempty(has_printed_diag)
    diag_vals = diag(Q_l);
    fprintf('=== DEBUG [%s]: diag(Q_l) first few values: %s ===\n', settings.PROC.name, num2str(diag_vals(1:min(10, end))'));
    has_printed_diag = true;
end

% === 3-Channel Robust Filtering Scheme (Phase & Doppler: Soft, Code: Hard) ===
for i = find(valid_idx)'
    % Bulletproof physical identification of Doppler: Doppler equations have 0 coordinate mapping
    is_doppler_i = (sum(abs(A(i, 1:3))) == 0);
    is_phase_i = ~is_doppler_i && (Q_l(i, i) < 0.05);
    force_soft_i = false;
    
    if is_phase_i
        % Phase channel: extremely relaxed threshold and force soft exclusion to protect phase lock
        k0_i = 15.0;
        k1_i = 30.0;
        soft_factor_i = 1e-2;
        force_soft_i = true;
    elseif is_doppler_i
        % Doppler channel: speed estimation component, allow hard exclusion to filter out huge transient outliers
        k0_i = 6.0;
        k1_i = 15.0;
        soft_factor_i = 1e-3;
        force_soft_i = false;
    else
        % Code channel: strict IGGIII thresholds to completely drop multipath pseudorange outliers
        k0_i = k0;
        k1_i = k1;
        soft_factor_i = soft_factor;
    end

    abs_v = abs(v_std(i));
    if abs_v <= k0_i
        gamma(i) = 1.0;
    elseif abs_v > k0_i && abs_v <= k1_i
        % Downweighting region
        gamma(i) = (k0_i / abs_v) * ((k1_i - abs_v) / (k1_i - k0_i))^2;
        if (soft_exclusion || force_soft_i) && gamma(i) < soft_factor_i
            gamma(i) = soft_factor_i;
        end
    else
        % Exclusion region
        if soft_exclusion || force_soft_i
            % Soft downweighting: use a tiny factor to inflate variance instead of zeroing out design matrix
            gamma(i) = soft_factor_i;
            exclude_mask(i) = false;
        else
            % Hard exclusion
            gamma(i) = 0.0;
            exclude_mask(i) = true;
        end
    end
end



%% 4. Apply Robust Weights and Perform Implicit Exclusion
Q_l_robust = Q_l;
A_robust = A;
omc_robust = omc;

n_valid = sum(valid_idx);
n_excluded = sum(exclude_mask);

% Fallback Protection: if exclusion leaves too few observations (e.g. < 4 for 3D + receiver clock estimation),
% we fallback to extreme downweighting (gamma = 0.01) instead of absolute exclusion.
if (n_valid - n_excluded) < 4
    for i = find(valid_idx)'
        if exclude_mask(i)
            gamma(i) = 0.01;  % soft penalization instead of hard drop
            Q_l_robust(i, i) = Q_l(i, i) / gamma(i);
        elseif gamma(i) < 1.0
            Q_l_robust(i, i) = Q_l(i, i) / gamma(i);
        end
    end
else
    % Normal IGGIII execution
    for i = find(valid_idx)'
        if exclude_mask(i)
            % Implicit Exclusion: set design matrix coefficients to 0, innovation to 0, 
            % and inflate its observation variance to a huge value (1e10).
            % This mathematically eliminates the observation from state updates while preserving matrix dimensions.
            A_robust(i, :) = 0;
            omc_robust(i) = 0;
            Q_l_robust(i, i) = 1e10;
        elseif gamma(i) < 1.0
            % Adaptive Downweighting
            Q_l_robust(i, i) = Q_l(i, i) / gamma(i);
        end
    end
end

% --- Adaptive Process Noise Lock ---
% Sum up equivalent geometric weights of PHASE observations only (ensure they are not Doppler)
diag_Ql = diag(Q_l);
phase_indices = find(valid_idx & (diag_Ql < 0.05) & (sum(abs(A(:, 1:3)), 2) > 0));
n_eq_phase = sum(gamma(phase_indices));

% Keep track of epochs inside the filter to allow convergence phase free adjustments
persistent filter_epoch_counter;
persistent last_processed_run;
if isempty(filter_epoch_counter) || isempty(last_processed_run) || ~strcmp(last_processed_run, settings.PROC.name)
    filter_epoch_counter = 1;
    last_processed_run = settings.PROC.name;
else
    filter_epoch_counter = filter_epoch_counter + 1;
end

if filter_epoch_counter > 120 && n_eq_phase < 12.0
    % Weak phase geometry epoch: phase constraints are too weak to compress Random Walk noise.
    % Limit coordinate prior variance based on remaining equivalent geometry strength.
    % std_limit scales from 0.05 m (n_eq_phase=0) to 0.30 m (n_eq_phase=12)
    std_limit = 0.05 + 0.25 * (n_eq_phase / 12.0);
    max_prior_var = std_limit^2;
    for d = 1:3
        if Q_x_pred(d, d) > max_prior_var
            scale_factor = sqrt(max_prior_var / Q_x_pred(d, d));
            Q_x_pred(d, :) = Q_x_pred(d, :) * scale_factor;
            Q_x_pred(:, d) = Q_x_pred(:, d) * scale_factor;
        end
    end
    Q_x_pred(1:3, 1:3) = (Q_x_pred(1:3, 1:3) + Q_x_pred(1:3, 1:3)') / 2;
    
    persistent last_lock_epoch;
    if isempty(last_lock_epoch) || (now - last_lock_epoch) > 0.05/86400
        fprintf('=== [IGGIII ADVANCED] Weak phase geometry (n_eq_phase = %.2f, Epoch = %d). Adaptive coordinate prior std limit = %.2f m ===\n', n_eq_phase, filter_epoch_counter, std_limit);
        if n_eq_phase < 0.05
            diag_Ql = diag(Q_l);
            phase_indices = find(valid_idx & (diag_Ql < 0.05));
            fprintf('=== [DEBUG ZERO] Phase indices count: %d, Gamma: %s, v_std: %s ===\n', ...
                numel(phase_indices), num2str(gamma(phase_indices)'), num2str(v_std(phase_indices)'));
            fprintf('=== [DEBUG ZERO] diag_Ql first 10: %s, valid_idx first 10: %s ===\n', ...
                num2str(diag_Ql(1:min(10, end))'), num2str(valid_idx(1:min(10, end))'));
        end
        last_lock_epoch = now;
    end
end

%% 5. Robust Kalman Filtering
% Kalman Gain computation (using robust observation covariance matrix)
K = (Q_x_pred * A_robust') / (Q_l_robust + A_robust * Q_x_pred * A_robust');

% State update
x_ = x_pred + K * omc_robust;

% Covariance update (using robust matrices)
Q_x_ = (I - K*A_robust) * Q_x_pred * (I - K*A_robust)' + K * Q_l_robust * K';

% Ensure symmetry of parameter covariance matrix
Q_x_ = (Q_x_ + Q_x_')/2;


%% 6. Save and Return Results
param = x_;
param_sigma = Q_x_;
float = true;

% Assign robustified matrices back to output variables
omc = omc_robust;
A = A_robust;
Q_l = Q_l_robust;

end
