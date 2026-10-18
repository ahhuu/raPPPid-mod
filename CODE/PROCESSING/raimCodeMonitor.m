function [Epoch, diagnostic] = raimCodeMonitor(Epoch, Adjust, settings)
%RAIMCODEMONITOR Monitor code-observation consistency without exclusion.
%   This is the first, deliberately non-invasive RAIM integration stage.
%   It performs a weighted least-squares residual global test on the valid
%   code rows that already exist in Adjust.A/Adjust.omc/Adjust.Q.  It never
%   changes Epoch.exclude, Epoch.cs_found, Adjust, or the PPP solution.
%
%   WLS fits global code-sensitive states, conditional on the current
%   per-satellite ionosphere estimates. This is not an integrity guarantee.
%   Innovation mode includes predicted PPP state covariance.

diagnostic = emptyDiagnostic();

if ~isfield(settings, 'PROC') || ~isfield(settings.PROC, 'raim')
    return;
end
cfg = settings.PROC.raim;
if ~isfield(cfg, 'enable') || ~logical(cfg.enable)
    return;
end
if ~isfield(cfg, 'mode') || isempty(cfg.mode)
    cfg.mode = 'monitor_only';
end
if ~strcmpi(cfg.mode, 'monitor_only')
    diagnostic.status = 'unsupported_mode';
    Epoch.raim = diagnostic;
    return;
end
if ~isfield(cfg, 'pfa_global') || ~isfinite(cfg.pfa_global) ...
        || cfg.pfa_global <= 0 || cfg.pfa_global >= 1
    cfg.pfa_global = 1e-3;
end
if ~isfield(cfg, 'min_redundancy') || ~isfinite(cfg.min_redundancy)
    cfg.min_redundancy = 1;
end
cfg.min_redundancy = max(1, round(cfg.min_redundancy));
if ~isfield(cfg,'test_model') || isempty(cfg.test_model)
    cfg.test_model = 'wls_residual';
end

required = {'A','omc','Q'};
if ~all(isfield(Adjust, required))
    diagnostic.status = 'missing_adjustment_data';
    Epoch.raim = diagnostic;
    return;
end

[code_rows, sat_index, freq_index] = getCodeRows(Epoch, settings, size(Adjust.A,1));
if isempty(code_rows)
    diagnostic.status = 'no_code_rows';
    Epoch.raim = diagnostic;
    return;
end

% Use every global code-sensitive state (XYZ, ZWD, receiver clocks, DCBs,
% and optional BDS-3 ISB). Ambiguities and per-satellite ionosphere states
% follow Adjust.NO_PARAM and are deliberately excluded so that the
% single-epoch monitor retains redundancy.
if isfield(Adjust,'NO_PARAM') && isfinite(Adjust.NO_PARAM)
    candidate_cols = 1:min(round(Adjust.NO_PARAM),size(Adjust.A,2));
else
    % Backward-compatible fallback for isolated tests/older callers.
    candidate_cols = [1 2 3 5 8 11 14 17 20];
end
candidate_cols = candidate_cols(candidate_cols <= size(Adjust.A,2));
H_all = Adjust.A(code_rows, candidate_cols);
A_code_all = Adjust.A(code_rows,:);
y_all = Adjust.omc(code_rows);
Q_all = Adjust.Q(code_rows, code_rows);

valid = isfinite(y_all) & any(H_all ~= 0, 2);
valid = valid & isfinite(diag(Q_all)) & diag(Q_all) > 0;
if any(~isfinite(Q_all(:)))
    finite_q = all(isfinite(Q_all),2) & all(isfinite(Q_all),1)';
    valid = valid & finite_q;
end

H = H_all(valid,:);
A_code = A_code_all(valid,:);
y = y_all(valid);
Q = Q_all(valid,valid);
sat_used = sat_index(valid);
freq_used = freq_index(valid);

active_cols = any(H ~= 0,1);
H = H(:,active_cols);
diagnostic.enabled = true;
diagnostic.mode = 'monitor_only';
diagnostic.test_model = char(cfg.test_model);
diagnostic.n_observations = numel(y);
diagnostic.pfa_global = cfg.pfa_global;

if isempty(y)
    diagnostic.status = 'insufficient_redundancy';
    Epoch.raim = diagnostic;
    return;
end

if strcmpi(cfg.test_model,'innovation')
    if ~isfield(Adjust,'param_sigma_pred') || ...
            size(Adjust.param_sigma_pred,1) ~= size(A_code,2)
        diagnostic.status = 'missing_state_covariance';
        Epoch.raim = diagnostic;
        return;
    end
    % Normalized innovation squared for recursive PPP. Unlike a standalone
    % WLS residual test, this includes uncertainty of all predicted PPP
    % states, including ambiguities and estimated ionosphere parameters.
    Q = Q + A_code * Adjust.param_sigma_pred * A_code';
    % omc is linearized at param, which may differ from param_pred after
    % ionosphere initialization. Translate to the same prior as covariance.
    if isfield(Adjust,'param') && isfield(Adjust,'param_pred')
        y = y + A_code*(Adjust.param(:)-Adjust.param_pred(:));
    end
elseif ~strcmpi(cfg.test_model,'wls_residual')
    diagnostic.status = 'unsupported_test_model';
    Epoch.raim = diagnostic;
    return;
end

result = raimResidualTest(y,H,Q,cfg.pfa_global,cfg.min_redundancy,cfg.test_model);
diagnostic.dof = result.dof;
diagnostic.n_parameters = result.n_parameters;
diagnostic.status = result.status;
diagnostic.covariance_rcond = result.covariance_rcond;
if ~result.available
    Epoch.raim = diagnostic;
    return;
end

w = result.standardized_residual;

diagnostic.available = true;
diagnostic.statistic = result.statistic;
diagnostic.threshold = result.threshold;
diagnostic.pass = result.pass;
diagnostic.status = ternary(diagnostic.pass, 'pass', 'fault_detected');
diagnostic.residual_m = result.residual_m;
diagnostic.standardized_residual = w;
diagnostic.satellite = Epoch.sats(sat_used);
diagnostic.frequency = freq_used;
if isempty(w)
    diagnostic.max_standardized_residual = NaN;
    diagnostic.candidate_satellite = NaN;
    diagnostic.candidate_frequency = NaN;
else
    [diagnostic.max_standardized_residual, idx_max] = max(w,[],'omitnan');
    diagnostic.candidate_satellite = diagnostic.satellite(idx_max);
    diagnostic.candidate_frequency = diagnostic.frequency(idx_max);
end

Epoch.raim = diagnostic;
end


function [rows, sat_index, freq_index] = getCodeRows(Epoch, settings, no_rows)
rows = [];
sat_index = [];
freq_index = [];

no_sats = numel(Epoch.sats);
no_freq = settings.INPUT.proc_freqs;
no_code = no_sats * no_freq;
if no_sats == 0 || no_code == 0
    return;
end

method = settings.PROC.method;
if strcmpi(method, 'Doppler')
    return;
elseif strcmpi(method, 'Code + Phase')
    rows = (1:2:(2*no_code))';
else
    % Code Only, smoothed-code, and Code + Doppler place code first.
    rows = (1:no_code)';
end
rows = rows(rows <= no_rows);

linear = (1:no_code)';
linear = linear(1:numel(rows));
sat_index = mod(linear-1, no_sats) + 1;
freq_index = floor((linear-1)/no_sats) + 1;
end


function out = emptyDiagnostic()
out = struct( ...
    'enabled', false, ...
    'mode', 'off', ...
    'test_model', 'off', ...
    'covariance_rcond', NaN, ...
    'available', false, ...
    'status', 'disabled', ...
    'pass', false, ...
    'statistic', NaN, ...
    'threshold', NaN, ...
    'pfa_global', NaN, ...
    'dof', 0, ...
    'n_observations', 0, ...
    'n_parameters', 0, ...
    'residual_m', [], ...
    'standardized_residual', [], ...
    'satellite', [], ...
    'frequency', [], ...
    'max_standardized_residual', NaN, ...
    'candidate_satellite', NaN, ...
    'candidate_frequency', NaN);
end


function value = ternary(condition, value_true, value_false)
if condition
    value = value_true;
else
    value = value_false;
end
end
