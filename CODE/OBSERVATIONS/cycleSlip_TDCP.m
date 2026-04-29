function [Epoch] = cycleSlip_TDCP(Epoch, settings, input, last_pos, obs)
% Performs cycle-slip detection based on Time-Differenced Carrier Phase (TDCP) 
% post-fit residuals. This method estimates the receiver velocity and clock 
% drift using a Least Squares approach and identifies cycle slips as outliers.
%
%  INPUT:
%   Epoch       struct, epoch-specific data
%   settings    struct, settings from GUI
%   input       struct, input data (ephemeris, etc.)
%   last_pos    3x1 double, current approximate receiver position [X; Y; Z]
%               (PPP_main passes `Adjust.param(1:3)` when available,
%                otherwise `settings.INPUT.pos_approx`). This position is
%               used as the geometric reference for modelling and should
%               represent the best current estimate (not necessarily the
%               previous-epoch raw position).
% OUTPUT:
%   Epoch       updated with .cs_found_TDCP and combined .cs_found
%
% 2026/04/28, Antigravity: Implementation based on TDCP residuals proposal
% *************************************************************************

% 0. Initial checks
if isempty(Epoch.old) || isempty(Epoch.old.sats)
    return;
end

% Get parameters or defaults
threshold = 0.05; % default 5cm
if isfield(settings.OTHER.CS, 'TDCP_threshold')
    threshold = settings.OTHER.CS.TDCP_threshold;
end

sigma0_threshold = 0.03; % default 3cm
if isfield(settings.OTHER.CS, 'TDCP_sigma0')
    sigma0_threshold = settings.OTHER.CS.TDCP_sigma0;
end

% 1. Find common satellites
[sats_common, idx_curr, idx_old] = intersect(Epoch.sats, Epoch.old.sats);
if isempty(sats_common)
    return;
end

% 3. Calculate modeled range difference
% We temporarily set proc_freqs to 1 to simplify modeling for CS detection
orig_proc_freqs = settings.INPUT.proc_freqs;
settings.INPUT.proc_freqs = 1;

% Current epoch modeling
% Use provided `last_pos` as the current approximate receiver position
% (see header note). If PPP_main supplied `Adjust.param(1:3)` this will be
% the current solution; otherwise pos_approx is used.
param_curr = [last_pos; zeros(5,1)]; 
[model_curr, ~] = modelApproximately(settings, input, Epoch, param_curr, obs, 1);

% Previous epoch modeling uses same receiver approx position to keep
% model differences consistent (we model satellite-side/time differences).
param_old = [last_pos; zeros(5,1)];
[model_old, ~] = modelApproximately(settings, input, Epoch.old, param_old, obs, 1);

% Restore settings
settings.INPUT.proc_freqs = orig_proc_freqs;
m = numel(Epoch.sats);
nfreq = size(Epoch.cs_found, 2);
cs_found_tdcp = false(m, 1);
tdcp_v = nan(m, 1);
final_sigma0 = nan;
final_clock_term = nan;
tdcp_freq_used = nan;
median_omc_final = nan;

phase_fields = {'L1', 'L2', 'L3'};
max_freq = min(settings.INPUT.proc_freqs, numel(phase_fields));
tdcp_v_freq = NaN(m, max_freq);
tdcp_sigma0_freq = NaN(1, max_freq);
tdcp_median_omc_freq = NaN(1, max_freq);
tdcp_clock_term_freq = NaN(1, max_freq);
tdcp_n_sats_freq = NaN(1, max_freq);

% 4. Iterative Least Squares
m = numel(Epoch.sats);
for freq = 1:max_freq
    phase_field = phase_fields{freq};
    raw_field = [phase_field '_raw'];

    if isfield(Epoch, raw_field) && ~isempty(Epoch.(raw_field))
        phase_curr_all = Epoch.(raw_field);
    elseif isfield(Epoch, phase_field) && ~isempty(Epoch.(phase_field))
        phase_curr_all = Epoch.(phase_field);
    else
        continue;
    end

    if isfield(Epoch.old, raw_field) && ~isempty(Epoch.old.(raw_field))
        phase_old_all = Epoch.old.(raw_field);
    elseif isfield(Epoch.old, phase_field) && ~isempty(Epoch.old.(phase_field))
        phase_old_all = Epoch.old.(phase_field);
    else
        continue;
    end

    phase_curr = phase_curr_all(idx_curr);
    phase_old = phase_old_all(idx_old);
    valid_freq = ~isnan(phase_curr) & ~isnan(phase_old);
    if sum(valid_freq) < 5
        continue;
    end

    idx_curr_f = idx_curr(valid_freq);
    idx_old_f = idx_old(valid_freq);
    phase_curr = phase_curr(valid_freq);
    phase_old = phase_old(valid_freq);
    n_common_f = sum(valid_freq);

    obs_tdcp = phase_curr - phase_old;

    rho_t = model_curr.rho(idx_curr_f);
    rho_t_1 = model_old.rho(idx_old_f);
    model_tdcp = rho_t - rho_t_1;
    if isfield(model_curr, 'dT_sat_rel') && isfield(model_old, 'dT_sat_rel')
        model_tdcp = model_tdcp - Const.C * (model_curr.dT_sat_rel(idx_curr_f) - model_old.dT_sat_rel(idx_old_f));
    end

    active_idx = true(n_common_f, 1);
    max_iter = floor(n_common_f / 3);
    if max_iter < 1
        continue;
    end

    for iter = 1:max_iter
        curr_n = sum(active_idx);
        if curr_n < 5; break; end

        ex = (model_curr.Rot_X(1,idx_curr_f(active_idx))' - last_pos(1)) ./ rho_t(active_idx);
        ey = (model_curr.Rot_X(2,idx_curr_f(active_idx))' - last_pos(2)) ./ rho_t(active_idx);
        ez = (model_curr.Rot_X(3,idx_curr_f(active_idx))' - last_pos(3)) ./ rho_t(active_idx);

        A = [-ex, -ey, -ez, ones(curr_n, 1)];
        omc = obs_tdcp(active_idx) - model_tdcp(active_idx);

        P_diag = ones(curr_n, 1);
        elev_active = model_curr.el(idx_curr_f(active_idx));
        for i = 1:curr_n
            el_rad = elev_active(i) * pi/180;
            if el_rad < 0; el_rad = 0; end
            P_diag(i) = (sin(el_rad))^2;
        end
        P = diag(P_diag);

        try
            res = adjustment(A, P, omc, 4);
        catch
            break;
        end

        v = res.v;
        [max_v, max_v_idx] = max(abs(v));

        if isnan(tdcp_freq_used)
            tdcp_freq_used = freq;
            tdcp_v = nan(m, 1);
            final_sigma0 = nan;
            final_clock_term = nan;
        end
        if tdcp_freq_used == freq
            tdcp_v(idx_curr_f(active_idx)) = v;
            median_omc_final = median(omc);
            if isfield(res, 'x') && numel(res.x) >= 4
                final_clock_term = res.x(4);
            end
        end

        tdcp_v_freq(idx_curr_f(active_idx), freq) = v;
        tdcp_median_omc_freq(freq) = median(omc);

        redundancy = curr_n - 4;
        if redundancy > 0
            sigma0 = sqrt((v' * P * v) / redundancy);
        else
            sigma0 = max_v;
        end
        if sigma0 > 1.0; sigma0 = 1.0; end

        if tdcp_freq_used == freq
            final_sigma0 = sigma0;
            tdcp_sigma0_freq(freq) = sigma0;
            tdcp_clock_term_freq(freq) = final_clock_term;
            tdcp_n_sats_freq(freq) = curr_n;
        else
            tdcp_sigma0_freq(freq) = sigma0;
            if isfield(res, 'x') && ~isempty(res.x)
                tdcp_clock_term_freq(freq) = res.x(min(4, numel(res.x)));
            end
            tdcp_n_sats_freq(freq) = curr_n;
        end

        if max_v < threshold && sigma0 < sigma0_threshold
            break;
        else
            actual_active_indices = find(active_idx);
            target_sat_idx_in_common = actual_active_indices(max_v_idx);
            target_sat_idx_in_epoch = idx_curr_f(target_sat_idx_in_common);
            cs_found_tdcp(target_sat_idx_in_epoch) = true;
            active_idx(target_sat_idx_in_common) = false;
        end
    end
end

% 5. Update Epoch
if ~isfield(Epoch, 'cs_found_TDCP')
    Epoch.cs_found_TDCP = false(m, 1);
end
Epoch.cs_found_TDCP = cs_found_tdcp;

% Apply CS to all frequencies for the detected satellite
for f = 1:nfreq
    Epoch.cs_found(:,f) = Epoch.cs_found(:,f) | cs_found_tdcp;
end

% Store visualization data and statistics for post-processing
Epoch.TDCP_v = tdcp_v;
Epoch.TDCP_sigma0 = final_sigma0;
Epoch.TDCP_v_freq = tdcp_v_freq;
Epoch.TDCP_sigma0_freq = tdcp_sigma0_freq;
Epoch.TDCP_median_omc_freq = tdcp_median_omc_freq;
Epoch.TDCP_clock_term_freq = tdcp_clock_term_freq;
Epoch.TDCP_n_sats_freq = tdcp_n_sats_freq;
Epoch.TDCP_stats.median_omc = median_omc_final;
Epoch.TDCP_stats.n_sats = sum(~isnan(tdcp_v));
Epoch.TDCP_stats.sigma0 = final_sigma0;
Epoch.TDCP_stats.clock_term = final_clock_term;
Epoch.TDCP_stats.freq_used = tdcp_freq_used;

end
