function state = initSegmentColdStart(settings)
% Initialize state used only inside one independently reset segment.

settings = applyColdStartDefaults(settings);
window = settings.PROC.cold_start.window_epochs;

state.enabled = settings.PROC.cold_start.enable;
state.reset_epoch = 1;
state.age = 0;
state.history = NaN(window, 3, 410);
state.history_count = zeros(3, 410);
state.initialized = false(3, 410);
state.provisional = NaN(3, 410);
state.last_hold_count = 0;
state.last_initialized_count = 0;
state.last_code_downweighted = 0;
state.last_code_weight_min = 1;
end
