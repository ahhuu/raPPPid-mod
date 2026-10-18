function [init_ambs, Epoch, state, hold_phase] = ...
    AdjustPhase2CodeWindow(Epoch, init_ambs, state, settings, reset_epoch)
% Initialize phase-to-code leveling from a window inside the current segment.
% No observation or state from the preceding segment is retained.

settings = applyColdStartDefaults(settings);
cfg = settings.PROC.cold_start;
prns = Epoch.sats(:);
nfreq = min(3, settings.INPUT.proc_freqs);
hold_phase = false(numel(prns), nfreq);

if ~cfg.enable
    [init_ambs, Epoch] = AdjustPhase2Code(Epoch, init_ambs);
    return;
end

if state.reset_epoch ~= reset_epoch
    state = initSegmentColdStart(settings);
    state.reset_epoch = reset_epoch;
end
state.age = Epoch.q - state.reset_epoch + 1;

phase_names = {'L1','L2','L3'};
lambda_names = {'l1','l2','l3'};
window = cfg.window_epochs;
slot = mod(max(state.age, 1) - 1, window) + 1;
newly_initialized = 0;

for f = 1:nfreq
    if ~isfield(Epoch, phase_names{f}) || isempty(Epoch.(phase_names{f}))
        continue;
    end
    phase = Epoch.(phase_names{f});
    lambda = Epoch.(lambda_names{f});
    amb_sample = (Epoch.C1 - phase) ./ lambda;
    valid = isfinite(amb_sample) & isfinite(lambda) & lambda > 0;

    valid_prns = prns(valid);
    state.history(slot, f, valid_prns) = amb_sample(valid);
    counts = squeeze(sum(isfinite(state.history(:, f, valid_prns)), 1));
    state.history_count(f, valid_prns) = counts(:)';

    % Keep a fixed first-sample leveling value while phase is withheld.
    missing_provisional = isnan(state.provisional(f, prns))' & valid;
    if any(missing_provisional)
        pp = prns(missing_provisional);
        state.provisional(f, pp) = floor(amb_sample(missing_provisional));
    end

    if state.age >= window
        candidate_mask = ~state.initialized(f, prns)';
        candidates = prns(candidate_mask);
        for k = 1:numel(candidates)
            prn = candidates(k);
            samples = state.history(:, f, prn);
            samples = samples(isfinite(samples));
            if numel(samples) >= cfg.min_samples
                init_ambs(f, prn) = floor(median(samples));
                state.initialized(f, prn) = true;
                newly_initialized = newly_initialized + 1;
            end
        end
    end

    use_permanent = state.initialized(f, prns)';
    leveling = state.provisional(f, prns)';
    leveling(use_permanent) = init_ambs(f, prns(use_permanent))';
    missing_leveling = ~isfinite(leveling);
    leveling(missing_leveling) = 0;
    Epoch.(phase_names{f}) = phase + lambda .* leveling;

    % Phase remains excluded until a segment-local window initialized it.
    hold_phase(:, f) = valid & ~use_permanent;
end

state.last_hold_count = nnz(hold_phase);
state.last_initialized_count = newly_initialized;
Epoch.cold_start_age = state.age;
Epoch.cold_start_hold_count = state.last_hold_count;
Epoch.cold_start_initialized_count = newly_initialized;
end
