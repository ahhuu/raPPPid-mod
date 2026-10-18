function settings = applyColdStartDefaults(settings)
% Add backward-compatible defaults for independent segment cold starts.

if ~isfield(settings.PROC, 'cold_start') || ~isstruct(settings.PROC.cold_start)
    settings.PROC.cold_start = struct();
end

cs = settings.PROC.cold_start;
cs = setDefault(cs, 'enable', false);
cs = setDefault(cs, 'mode', 'multi_epoch');
cs = setDefault(cs, 'window_epochs', 10);
cs = setDefault(cs, 'min_samples', 3);
cs = setDefault(cs, 'ambiguity_init', 'median_code_phase');
cs = setDefault(cs, 'robust_code', false);
cs = setDefault(cs, 'huber_c', 1.5);
cs = setDefault(cs, 'scale_floor_m', 0.25);
cs = setDefault(cs, 'weight_floor', 0.05);
cs = setDefault(cs, 'failure_fallback', 'legacy_single_epoch');

cs.enable = logical(cs.enable);
cs.robust_code = logical(cs.robust_code);
cs.window_epochs = max(1, round(double(cs.window_epochs)));
cs.min_samples = max(1, round(double(cs.min_samples)));
cs.min_samples = min(cs.min_samples, cs.window_epochs);
cs.huber_c = max(eps, double(cs.huber_c));
cs.scale_floor_m = max(eps, double(cs.scale_floor_m));
cs.weight_floor = min(1, max(eps, double(cs.weight_floor)));

settings.PROC.cold_start = cs;
end

function s = setDefault(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
