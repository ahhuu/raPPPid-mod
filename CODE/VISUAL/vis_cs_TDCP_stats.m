function [] = vis_cs_TDCP_stats(storeData, ~)
% Plots TDCP statistics per frequency when available.
%
% Falls back to the legacy single summary plot if only scalar TDCP fields
% exist.
%
% 2026/04/29, Antigravity: add per-frequency TDCP visualization
% *************************************************************************

if ~isfield(storeData, 'cs_tdcp_median_omc') || isempty(storeData.cs_tdcp_median_omc)
    fprintf('No TDCP statistics available (cs_tdcp_median_omc not found).\n');
    return;
end

duration = (storeData.gpstime(end) - storeData.gpstime(1)) / 3600;
[vec, ticks] = duration2ticks(duration);
vec = storeData.gpstime(1) + vec;
time = storeData.gpstime(:);

has_per_freq = isfield(storeData, 'cs_tdcp_median_omc_freq') && ~isempty(storeData.cs_tdcp_median_omc_freq);

if has_per_freq
    [~, n_freq] = size(storeData.cs_tdcp_median_omc_freq);
    for freq = 1:n_freq
        if ~any(~isnan(storeData.cs_tdcp_median_omc_freq(:, freq)))
            continue;
        end
        plot_one_freq(storeData, time, vec, ticks, freq);
    end
else
    plot_legacy(storeData, time, vec, ticks);
end

end

function [] = plot_one_freq(storeData, time, vec, ticks, freq)
figure('Name', sprintf('TDCP Statistics - F%d', freq), ...
    'units', 'normalized', 'outerposition', [0.05 0.1 0.9 0.8], ...
    'NumberTitle', 'off');

subplot(3, 1, 1);
plot(time, storeData.cs_tdcp_median_omc_freq(:, freq), 'b-', 'LineWidth', 1.5);
hold on;
if isfield(storeData, 'cs_tdcp_clock_term_freq') && size(storeData.cs_tdcp_clock_term_freq, 2) >= freq
    plot(time, storeData.cs_tdcp_clock_term_freq(:, freq), 'm-', 'LineWidth', 1.2);
    legend('Raw median OMC', 'Estimated clock term', 'Location', 'best');
else
    legend('Raw median OMC', 'Location', 'best');
end
hline(0, 'k--');
grid on;
set(gca, 'XTick', vec, 'XTickLabel', ticks, 'fontSize', 9);
title(sprintf('TDCP Raw Median OMC and Estimated Clock Term (F%d)', freq), 'FontSize', 11, 'FontWeight', 'bold');
ylabel('[m]');
xlim([min(time) max(time)]);

subplot(3, 1, 2);
plot(time, storeData.cs_tdcp_sigma0_freq(:, freq), 'r-', 'LineWidth', 1.5);
grid on;
set(gca, 'XTick', vec, 'XTickLabel', ticks, 'fontSize', 9);
title(sprintf('TDCP Sigma0 (F%d)', freq), 'FontSize', 11, 'FontWeight', 'bold');
ylabel('\sigma_0 [m]');
xlim([min(time) max(time)]);

subplot(3, 1, 3);
plot(time, storeData.cs_tdcp_n_sats_freq(:, freq), 'g-', 'LineWidth', 1.5);
grid on;
set(gca, 'XTick', vec, 'XTickLabel', ticks, 'fontSize', 9);
title(sprintf('TDCP Number of Active Satellites (F%d)', freq), 'FontSize', 11, 'FontWeight', 'bold');
ylabel('# Satellites');
xlabel('Time [hh:mm]');
xlim([min(time) max(time)]);
set(gca, 'YTick', unique(round(get(gca, 'YTick'))));
end

function [] = plot_legacy(storeData, time, vec, ticks)
figure('Name', 'TDCP Iteration Statistics', ...
    'units', 'normalized', 'outerposition', [0.05 0.1 0.9 0.8], ...
    'NumberTitle', 'off');

subplot(3, 1, 1);
plot(time, storeData.cs_tdcp_median_omc, 'b-', 'LineWidth', 1.5);
hold on;
if isfield(storeData, 'cs_tdcp_clock_term') && ~isempty(storeData.cs_tdcp_clock_term)
    plot(time, storeData.cs_tdcp_clock_term, 'm-', 'LineWidth', 1.2);
    legend('Raw median OMC', 'Estimated clock term', 'Location', 'best');
else
    legend('Raw median OMC', 'Location', 'best');
end
hline(0, 'k--');
grid on;
set(gca, 'XTick', vec, 'XTickLabel', ticks, 'fontSize', 9);
title('TDCP Raw Median OMC and Estimated Clock Term', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('[m]');
xlim([min(time) max(time)]);

subplot(3, 1, 2);
plot(time, storeData.cs_tdcp_sigma0, 'r-', 'LineWidth', 1.5);
grid on;
set(gca, 'XTick', vec, 'XTickLabel', ticks, 'fontSize', 9);
title('TDCP Sigma0 (Unit Weight Error) per Epoch', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('\sigma_0 [m]');
xlim([min(time) max(time)]);

subplot(3, 1, 3);
if isfield(storeData, 'cs_tdcp_n_sats') && ~isempty(storeData.cs_tdcp_n_sats)
    plot(time, storeData.cs_tdcp_n_sats, 'g-', 'LineWidth', 1.5);
else
    fprintf('cs_tdcp_n_sats not available; skipping active satellites plot.\n');
    return;
end
grid on;
set(gca, 'XTick', vec, 'XTickLabel', ticks, 'fontSize', 9);
title('TDCP Number of Active Satellites per Epoch', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('# Satellites');
xlabel('Time [hh:mm]');
xlim([min(time) max(time)]);
set(gca, 'YTick', unique(round(get(gca, 'YTick'))));
end
