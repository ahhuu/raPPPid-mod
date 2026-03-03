function vis_plotBDS23ISB(hours, strXAxis, param, resets_h, settings)
% Plots BDS-2/BDS-3 Inter-System Bias analysis:
%   Subplot 1: BDS-2 and BDS-3 receiver clock offsets time series
%   Subplot 2: ISB = dt_BDS3 - dt_BDS2 time series with trend line
%   Subplot 3: ISB histogram with mean/std statistics
%
% INPUT:
%   hours       vector, time in hours from beginning of processing
%   strXAxis    label for x-axis
%   param       estimated parameters of all processed epochs (NO_PARAM x epochs)
%   resets_h    vector, time of resets in hours
%   settings    struct, processing settings from GUI
% OUTPUT:
%   []
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Glaner
% *************************************************************************

% Check prerequisites
if ~isfield(settings.BIASES, 'estimate_bds23_isb') || ~settings.BIASES.estimate_bds23_isb
    fprintf('BDS-2/BDS-3 ISB estimation is not enabled.\n');
    return
end
if ~settings.INPUT.use_BDS
    fprintf('BDS is not enabled, cannot plot ISB.\n');
    return
end

m2ns = 1e9 / Const.C;       % convert from [m] to [ns]
bds23_isb_mode = 'free';
if isfield(settings.BIASES, 'bds23_isb_mode')
    bds23_isb_mode = settings.BIASES.bds23_isb_mode;
end
bds23_isb_split_on = strcmp(bds23_isb_mode, 'split');
bds23_isb_fixed_on = strcmp(bds23_isb_mode, 'fixed');
bds23_isb_state_on = ~bds23_isb_fixed_on;

% Extract BDS-2 and BDS-3 receiver clock offsets [ns]
% free/constrained: param(14)=dt_BDS_common, param(20)=ISB_BDS3
% split:            param(14)=dt_BDS2,      param(20)=dt_BDS3
dt_BDS_common = param(14,:) * m2ns;
if bds23_isb_state_on && size(param,1) >= 20
    if bds23_isb_split_on
        dt_BDS2 = param(14,:) * m2ns;
        dt_BDS3 = param(20,:) * m2ns;
        dt_ISB = dt_BDS3 - dt_BDS2;         % split: ISB = dt_BDS3 - dt_BDS2
    else
        dt_ISB = param(20,:) * m2ns;        % free/constrained
        dt_BDS2 = dt_BDS_common;
        dt_BDS3 = dt_BDS_common + dt_ISB;
    end
else
    fixed_m = 0;
    if isfield(settings.BIASES, 'bds23_isb_fixed_m') && isfinite(settings.BIASES.bds23_isb_fixed_m)
        fixed_m = settings.BIASES.bds23_isb_fixed_m;
    end
    dt_ISB = fixed_m * m2ns * ones(size(dt_BDS_common));
    dt_BDS2 = dt_BDS_common;
    dt_BDS3 = dt_BDS_common + dt_ISB;
end

% valid epochs
if bds23_isb_split_on
    valid = (dt_BDS2 ~= 0) & (dt_BDS3 ~= 0) & isfinite(dt_ISB);
elseif bds23_isb_state_on
    valid = (dt_BDS_common ~= 0) & (dt_ISB ~= 0) & isfinite(dt_ISB);
else
    valid = (dt_BDS_common ~= 0);
end
ISB = dt_ISB;

% Create figure
fig_isb = figure('Name','BDS-2/BDS-3 ISB Analysis', 'NumberTitle','off');


%% Subplot 1: BDS-2 and BDS-3 clock offsets
subplot(3,1,1)
hold on
h1 = plot(hours(valid), dt_BDS2(valid), '-', 'Color', DEF.COLOR_C, 'DisplayName', 'BDS-2');
h2 = plot(hours(valid), dt_BDS3(valid), '-', 'Color', [0.5 0 0.5], 'DisplayName', 'BDS-3');
% Mark invalid epochs
idx_invalid_2 = (dt_BDS2 == 0);
idx_invalid_3 = (dt_BDS3 == 0);
if any(idx_invalid_2)
    plot(hours(idx_invalid_2), dt_BDS2(idx_invalid_2), 'k.', 'HandleVisibility', 'off')
end
if any(idx_invalid_3)
    plot(hours(idx_invalid_3), dt_BDS3(idx_invalid_3), 'k.', 'HandleVisibility', 'off')
end
% Style
if ~isempty(resets_h); vline(resets_h, 'k:'); end
legend([h1, h2], 'Location', 'best')
title('BDS-2 and BDS-3 Receiver Clock Offsets')
xlabel(strXAxis)
ylabel('Clock offset [ns]')
xlim([hours(1) hours(end)])
grid on
Grid_Xoff_Yon()


%% Subplot 2: ISB time series
subplot(3,1,2)
hold on
plot(hours(valid), ISB(valid), '-', 'Color', [0.85 0.33 0.10], 'DisplayName', 'ISB')
% Add mean line
if sum(valid) > 0
    isb_mean = mean(ISB(valid), 'omitnan');
    hline(isb_mean, 'r-');
    text(hours(find(valid,1,'first')), isb_mean, sprintf('  mean = %.2f ns', isb_mean), ...
        'Color', 'r', 'FontSize', 9, 'VerticalAlignment', 'bottom')
end
% Style
if ~isempty(resets_h); vline(resets_h, 'k:'); end
title('BDS-2/BDS-3 ISB (dt_{BDS3} - dt_{BDS2})')
xlabel(strXAxis)
ylabel('ISB [ns]')
xlim([hours(1) hours(end)])
grid on
Grid_Xoff_Yon()


%% Subplot 3: ISB histogram
subplot(3,1,3)
if sum(valid) > 1
    isb_valid = ISB(valid);
    isb_valid = isb_valid(~isnan(isb_valid));
    if numel(isb_valid) > 1
        histogram(isb_valid, 'Normalization', 'probability', ...
            'FaceColor', [0.85 0.33 0.10], 'EdgeColor', 'k')
        hold on
        % Statistics
        isb_mean = mean(isb_valid);
        isb_std  = std(isb_valid);
        isb_med  = median(isb_valid);
        % Mark mean with vertical line
        yl = ylim;
        plot([isb_mean isb_mean], yl, 'r-', 'LineWidth', 2)
        % Annotation
        str_stats = sprintf('Mean: %.3f ns\nStd: %.3f ns\nMedian: %.3f ns\nN: %d', ...
            isb_mean, isb_std, isb_med, numel(isb_valid));
        text(0.98, 0.95, str_stats, 'Units', 'normalized', ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
            'FontSize', 9, 'BackgroundColor', [1 1 1 0.8], 'EdgeColor', [0.5 0.5 0.5])
    end
end
title('ISB Distribution')
xlabel('ISB [ns]')
ylabel('Probability')
grid on

% add customized datatip
dcm = datacursormode(fig_isb);
datacursormode on
set(dcm, 'updatefcn', @vis_customdatatip_isb)

end



function output_txt = vis_customdatatip_isb(~, event_obj)
% Custom datatip for ISB plot
pos = get(event_obj, 'Position');

% try to interpret as time or value
output_txt = {};
i = 1;
if numel(pos) >= 2
    if pos(1) > 0 && pos(1) < 48   % likely hours
        sod = pos(1) * 3600;
        [~, hour, min, sec] = sow2dhms(sod);
        str_time = sprintf('%02.0f:%02.0f:%02.0f', hour, min, sec);
        output_txt{i} = ['Time: ', str_time]; i = i + 1;
    end
    output_txt{i} = sprintf('Value: %.3f ns', pos(2));
end
end
