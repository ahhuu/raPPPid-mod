function settings = applyPredictedPhaseDefaults(settings)
% Backward-compatible defaults for metadata-aware Doppler phase prediction.

if ~isfield(settings.PROC, 'predicted_phase') || ~isstruct(settings.PROC.predicted_phase)
    settings.PROC.predicted_phase = struct();
end
p = settings.PROC.predicted_phase;
if ~isfield(p, 'enable');                  p.enable = false; end
if ~isfield(p, 'metadata_file');           p.metadata_file = ''; end
if ~isfield(p, 'max_prediction_length');   p.max_prediction_length = inf; end
if ~isfield(p, 'sigma_scale');             p.sigma_scale = 1; end
if ~isfield(p, 'sigma_floor_m');           p.sigma_floor_m = 0.03; end
if ~isfield(p, 'time_tolerance_ms');       p.time_tolerance_ms = 2; end
if ~isfield(p, 'exclude_from_cycle_slip'); p.exclude_from_cycle_slip = true; end
if ~isfield(p, 'allowed_signals');          p.allowed_signals = {}; end
if ~isfield(p, 'quality_rms_file');         p.quality_rms_file = ''; end
if ~isfield(p, 'quality_max_rms_m');        p.quality_max_rms_m = inf; end
if ~isfield(p, 'quality_sigma_scale');      p.quality_sigma_scale = 1; end
if ~isfield(p, 'quality_min_samples');      p.quality_min_samples = 0; end
if ~isfield(p, 'reject_if_quality_missing'); p.reject_if_quality_missing = false; end
settings.PROC.predicted_phase = p;
end
