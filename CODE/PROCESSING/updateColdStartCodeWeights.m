function [Epoch, state] = updateColdStartCodeWeights(Epoch, state, settings)
% Robust code weights from code-minus-Doppler innovations within a segment.

settings = applyColdStartDefaults(settings);
cfg = settings.PROC.cold_start;
nfreq = min(3, settings.INPUT.proc_freqs);
weights = ones(numel(Epoch.sats), nfreq);

if ~cfg.enable || ~cfg.robust_code || state.age > cfg.window_epochs || ...
        isempty(Epoch.old) || isempty(Epoch.old.sats)
    Epoch.cold_start_code_weight = weights;
    Epoch.cold_start_code_downweighted = 0;
    Epoch.cold_start_code_weight_min = 1;
    return;
end

[~, idx_now, idx_old] = intersect(Epoch.sats, Epoch.old.sats, 'stable');
if isempty(idx_now)
    Epoch.cold_start_code_weight = weights;
    Epoch.cold_start_code_downweighted = 0;
    Epoch.cold_start_code_weight_min = 1;
    return;
end

dt = Epoch.gps_time - Epoch.old.gps_time;

if ~isfinite(dt) || dt <= 0 || dt > 10
    Epoch.cold_start_code_weight = weights;
    Epoch.cold_start_code_downweighted = 0;
    Epoch.cold_start_code_weight_min = 1;
    return;
end

code_names = {'C1','C2','C3'};
doppler_names = {'D1','D2','D3'};
lambda_names = {'l1','l2','l3'};
systems = [Epoch.gps, Epoch.glo, Epoch.gal, Epoch.bds, Epoch.qzss];

for f = 1:nfreq
    if ~isfield(Epoch, code_names{f}) || ~isfield(Epoch.old, code_names{f}) || ...
            isempty(Epoch.(code_names{f})) || isempty(Epoch.old.(code_names{f})) || ...
            isempty(Epoch.(doppler_names{f})) || isempty(Epoch.old.(doppler_names{f}))
        continue;
    end
    c_now = Epoch.(code_names{f})(idx_now);
    c_old = Epoch.old.(code_names{f})(idx_old);
    d_now = Epoch.(doppler_names{f})(idx_now);
    d_old = Epoch.old.(doppler_names{f})(idx_old);
    l_now = Epoch.(lambda_names{f})(idx_now);
    innovation = (c_now - c_old) + 0.5 .* (d_now + d_old) .* l_now .* dt;

    for sys = 1:size(systems,2)
        group_local = find(systems(idx_now,sys));
        if numel(group_local) < 4
            continue;
        end
        values = innovation(group_local);
        valid = isfinite(values);
        if nnz(valid) < 4
            continue;
        end
        center = median(values(valid));
        scale = 1.4826 * median(abs(values(valid) - center));
        scale = max(scale, cfg.scale_floor_m);
        u = abs(values - center) ./ (cfg.huber_c * scale);
        w = ones(size(values));
        down = isfinite(u) & u > 1;
        w(down) = 1 ./ u(down);
        w = max(cfg.weight_floor, min(1, w));
        weights(idx_now(group_local), f) = w;
    end
end

Epoch.cold_start_code_weight = weights;
Epoch.cold_start_code_downweighted = nnz(weights < 0.999);
Epoch.cold_start_code_weight_min = min(weights(:));
state.last_code_downweighted = Epoch.cold_start_code_downweighted;
state.last_code_weight_min = Epoch.cold_start_code_weight_min;
end
