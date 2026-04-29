function [] = vis_cs_TDCP(storeData, sys, threshold, sigma0_threshold)
% Plots TDCP residuals and sigma0, per frequency when available.
%
% INPUT:
%   storeData        struct, collected data from all processed epochs
%   sys              char, GNSS identifier (G, R, E, C, J)
%   threshold        residual threshold [m]
%   sigma0_threshold sigma0 threshold [m]
%
% 2026/04/29, Antigravity: frequency-aware TDCP visualization
% *************************************************************************

if ~isfield(storeData, 'cs_tdcp_v') || isempty(storeData.cs_tdcp_v)
    return;
end

% time and ticks
duration = (storeData.gpstime(end) - storeData.gpstime(1)) / 3600;
[vec, ticks] = duration2ticks(duration);
vec = storeData.gpstime(1) + vec;
time = storeData.gpstime(:);

has_per_freq = isfield(storeData, 'cs_tdcp_v_freq') && ~isempty(storeData.cs_tdcp_v_freq);

if has_per_freq
    [~, ~, n_freq] = size(storeData.cs_tdcp_v_freq);
    for freq = 1:n_freq
        residuals = storeData.cs_tdcp_v_freq(:, :, freq);
        if ~any(any(~isnan(residuals) & residuals ~= 0))
            continue;
        end
        plotSigma0(time, storeData, vec, ticks, sigma0_threshold, sys, freq);
        plotResiduals(time, residuals, storeData.cs_found, threshold, vec, ticks, sys, freq);
    end
else
    plotSigma0(time, storeData, vec, ticks, sigma0_threshold, sys, []);
    plotResiduals(time, storeData.cs_tdcp_v, storeData.cs_found, threshold, vec, ticks, sys, []);
end

end

function [] = plotSigma0(time, storeData, vec, ticks, sigma0_threshold, sys, freq)
if isempty(freq)
    sigma0 = storeData.cs_tdcp_sigma0;
    fig_name = ['TDCP Sigma0 (Unit Weight Error), ' char2gnss(sys)];
    title_txt = ['TDCP Sigma0 - Epoch Quality Indicator (' char2gnss(sys) ')'];
else
    sigma0 = storeData.cs_tdcp_sigma0_freq(:, freq);
    fig_name = sprintf('TDCP Sigma0 (Unit Weight Error), %s F%d', char2gnss(sys), freq);
    title_txt = sprintf('TDCP Sigma0 - Epoch Quality Indicator (%s F%d)', char2gnss(sys), freq);
end

figure('Name', fig_name, 'units','normalized', 'outerposition',[0.1 0.1 0.8 0.4], 'NumberTitle','off');
plot(time, sigma0, 'b-', 'LineWidth', 1);
hold on;
hline(sigma0_threshold, 'r--', sprintf('Threshold: %.3fm', sigma0_threshold));
grid on;
set(gca, 'XTick', vec, 'XTickLabel', ticks, 'fontSize', 10);
title(title_txt);
xlabel('Time [hh:mm]');
ylabel('\sigma_0 [m]');
xlim([min(time) max(time)]);
end

function [] = plotResiduals(time, residuals, cs_found, threshold, vec, ticks, sys, freq)
% Helper to plot satellite-specific residuals
if sys == 'G'
    loop = 1:99;
    col = DEF.COLOR_G;
elseif sys == 'R'
    loop = 101:199;
    col = DEF.COLOR_R;
elseif sys == 'E'
    loop = 201:299;
    col = DEF.COLOR_E;
elseif sys == 'C'
    loop = 301:399;
    col = DEF.COLOR_C;
elseif sys == 'J'
    loop = 401:410;
    col = DEF.COLOR_J;
else
    return;
end

if isempty(freq)
    fig_name = ['TDCP Post-fit Residuals, ' char2gnss(sys)];
else
    fig_name = sprintf('TDCP Post-fit Residuals, %s F%d', char2gnss(sys), freq);
end

fig_res = figure('Name', fig_name, 'units','normalized', 'outerposition',[0 0 1 1], 'NumberTitle','off');
ii = 1;
dcm = datacursormode(fig_res);
set(dcm, 'updatefcn', @vis_customdatatip_CycleSlip);

for i = loop
    data = full(residuals(:,i));
    if all(isnan(data) | data == 0)
        continue;
    end
    
    if ii == 17
        fig_res = figure('Name', fig_name, 'units','normalized', 'outerposition',[0 0 1 1], 'NumberTitle','off');
        dcm = datacursormode(fig_res);
        set(dcm, 'updatefcn', @vis_customdatatip_CycleSlip);
        ii = 1;
    end
    
    subplot(4, 4, ii);
    ii = ii + 1;
    
    plot(time, data, '.', 'Color', col);
    hold on;
    hline(threshold, 'g:');
    hline(-threshold, 'g:');
    
    cs_idx = logical(full(cs_found(:,i)));
    valid_len = min([numel(time), numel(data), numel(cs_idx)]);
    cs_idx = cs_idx(1:valid_len);
    
    if any(cs_idx)
        plot(time(cs_idx), data(cs_idx), 'ro', 'MarkerSize', 4);
    end
    
    grid on;
    set(gca, 'XTick', vec, 'XTickLabel', ticks, 'fontSize', 8);
    if isempty(freq)
        title([char2gnss(sys) sprintf('%02d', mod(i,100))]);
    else
        title([char2gnss(sys) sprintf('%02d', mod(i,100)) sprintf(' F%d', freq)]);
    end
    xlabel('Time [hh:mm]');
    ylabel('v [m]');
    xlim([min(time) max(time)]);
    ylim([-threshold*3, threshold*3]);
end
end
