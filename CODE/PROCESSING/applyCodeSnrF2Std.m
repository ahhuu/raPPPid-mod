function [VAR_code, sigma_f2] = applyCodeSnrF2Std(VAR_code, Epoch, settings)
% Apply an SNR-dependent raw-code standard deviation to frequency 2 only.
%
% The carrier-phase covariance and code frequencies 1/3 are deliberately
% untouched.  At high C/N0 the frequency-specific standard deviation from
% settings.ADJ.var_code_frq is retained.  At low C/N0 it is replaced by a
% conservative standard deviation, with linear interpolation in-between.

sigma_f2 = [];
if size(VAR_code, 2) < 2 || ~isfield(settings, 'ADJ') || ...
        ~isfield(settings.ADJ, 'code_snr_f2')
    return;
end

cfg = settings.ADJ.code_snr_f2;
if ~isfield(cfg, 'enable') || ~cfg.enable
    return;
end

cfg = fillDefaults(cfg);
n_sats = size(VAR_code, 1);
if ~isfield(Epoch, 'S2') || numel(Epoch.S2) ~= n_sats
    return;
end

snr = Epoch.S2(:);
sigma_f2 = sqrt(VAR_code(:,2));
variance_f2 = VAR_code(:,2);
update_mask = false(n_sats,1);
apply_mask = false(n_sats,1);
apply_mask = apply_mask | enabledSystemMask(Epoch, 'gps',  cfg.systems.GPS,  n_sats);
apply_mask = apply_mask | enabledSystemMask(Epoch, 'glo',  cfg.systems.GLO,  n_sats);
apply_mask = apply_mask | enabledSystemMask(Epoch, 'gal',  cfg.systems.GAL,  n_sats);
apply_mask = apply_mask | enabledSystemMask(Epoch, 'bds',  cfg.systems.BDS,  n_sats);
apply_mask = apply_mask | enabledSystemMask(Epoch, 'qzss', cfg.systems.QZSS, n_sats);

valid_snr = isfinite(snr) & snr > 0;
if strcmpi(cfg.missing_snr, 'low')
    missing_mask = apply_mask & ~valid_snr;
    sigma_f2(missing_mask) = cfg.low_std;
    update_mask = update_mask | missing_mask;
end

idx = apply_mask & valid_snr;
if any(idx)
    t = (snr(idx) - cfg.low_snr) ./ (cfg.high_snr - cfg.low_snr);
    t = max(0, min(1, t));
    base_sigma = sigma_f2(idx);
    sigma_f2(idx) = cfg.low_std + t .* (base_sigma - cfg.low_std);
    update_mask = update_mask | (idx & snr < cfg.high_snr);
end

variance_f2(update_mask) = sigma_f2(update_mask).^2;
VAR_code(:,2) = variance_f2;
end


function cfg = fillDefaults(cfg)
if ~isfield(cfg, 'low_snr');     cfg.low_snr = 30; end
if ~isfield(cfg, 'high_snr');    cfg.high_snr = 40; end
if ~isfield(cfg, 'low_std');     cfg.low_std = 2.0; end
if ~isfield(cfg, 'missing_snr'); cfg.missing_snr = 'base'; end
if ~isfield(cfg, 'systems') || ~isstruct(cfg.systems)
    cfg.systems = struct();
end
names = {'GPS','GLO','GAL','BDS','QZSS'};
for k = 1:numel(names)
    if ~isfield(cfg.systems, names{k})
        cfg.systems.(names{k}) = strcmp(names{k}, 'GPS');
    end
end
assert(isfinite(cfg.low_snr) && isfinite(cfg.high_snr) && ...
    cfg.high_snr > cfg.low_snr, ...
    'code_snr_f2.high_snr must be greater than low_snr.');
assert(isfinite(cfg.low_std) && cfg.low_std > 0, ...
    'code_snr_f2.low_std must be positive.');
assert(any(strcmpi(cfg.missing_snr, {'base','low'})), ...
    'code_snr_f2.missing_snr must be base or low.');
end


function mask = enabledSystemMask(Epoch, field_name, enabled, n_sats)
mask = false(n_sats,1);
if enabled && isfield(Epoch, field_name)
    values = logical(Epoch.(field_name));
    if numel(values) == n_sats
        mask = values(:);
    end
end
end
