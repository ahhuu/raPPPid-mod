function settings = applyQualityControlDefaults(settings)
% Fill missing fields only; preserve historical experiment values.
rows=qualityControlSchema();
for k=1:size(rows,1)
    [~,~,found]=qualityControlField(settings,rows{k,2});
    if ~found; settings=qualityControlField(settings,rows{k,2},rows{k,4}); end
end
% Do not clamp user values here: validation must reject invalid input.
hidden={'mode','multi_epoch';'ambiguity_init','median_code_phase'; ...
    'failure_fallback','legacy_single_epoch'};
for k=1:size(hidden,1)
    if ~isfield(settings.PROC.cold_start,hidden{k,1})
        settings.PROC.cold_start.(hidden{k,1})=hidden{k,2};
    end
end
if ~isfield(settings.PROC.raim,'mode'); settings.PROC.raim.mode='monitor_only'; end
end
