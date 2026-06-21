function [] = vis_cs_TDCP(storeData, sys, threshold, sigma0_threshold)
% Plots the cycle slip detection based on Time-Differenced Carrier Phase
% (TDCP) post-fit residuals (check cycleSlip_TDCP.m) for all satellites.
%
% INPUT:
%   storeData           struct, collected data from all processed epochs
%   sys                 1-digit-char which represents GNSS (G=GPS, R=Glonass, E=Galileo)
%   threshold           [m], threshold for maximum TDCP residual
%   sigma0_threshold    [m], threshold for overall sigma0
% OUTPUT:
%   []
%
% Revision:
%   2026/06/04, ahhuu: initial implementation
%
% using hline.m (c) 2001, Brandon Kuczenski
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************


% time of resets in seconds of week
reset_sow = storeData.gpstime(storeData.float_reset_epochs);

duration = storeData.gpstime(end) - storeData.gpstime(1);     % total time of processing [sec]
duration = duration/3600;                                       % ... [h]

% create ticks
[vec, ticks] = duration2ticks(duration);
vec = mod(storeData.gpstime(1),86400) + vec;

% Plot the TDCP residuals
cs_tdcp_v = full(storeData.cs_tdcp_v);
plotit(mod(storeData.gpstime,86400), cs_tdcp_v, threshold, sigma0_threshold, ...
    vec, ticks, ['TDCP, ' sys], sys, mod(reset_sow, 86400))

% Plot sigma0 over time
if ~all(isnan(storeData.cs_tdcp_sigma0))
    figur_sigma0 = figure('Name', ['TDCP sigma0: ' char2gnss(sys)], ...
        'units','normalized', 'outerposition',[0 0 1 1], 'NumberTitle','off');

    % Time axis
    x = mod(storeData.gpstime, 86400);

    subplot(2,1,1)
    plot(x, storeData.cs_tdcp_sigma0, 'b-', 'LineWidth', 1.5)
    hold on
    hline(sigma0_threshold, 'r--')        % plot sigma0 threshold
    hold off
    grid on
    set(gca, 'XTick', vec, 'XTickLabel', ticks)
    set(gca, 'fontSize', 10)
    title(['TDCP sigma0: ' char2gnss(sys)])
    xlabel('Time [hh:mm]')
    ylabel('sigma0 [m]')
    legend('\sigma_0', ['threshold = ' sprintf('%.3f', sigma0_threshold) ' m'], 'Location','best')
    xlim([min(x(x~=0)) max(x(x~=0))])

    % Number of satellites used per epoch
    if isfield(storeData, 'cs_tdcp_n_sats_freq') && ~all(isnan(storeData.cs_tdcp_n_sats_freq(:)))
        subplot(2,1,2)
        freq_used = storeData.cs_tdcp_freq_used;
        n_sats = NaN(size(freq_used));
        for q = 1:length(freq_used)
            if ~isnan(freq_used(q)) && freq_used(q) > 0
                n_sats(q) = storeData.cs_tdcp_n_sats_freq(q, freq_used(q));
            end
        end
        plot(x, n_sats, 'k.-', 'LineWidth', 1, 'MarkerSize', 8)
        grid on
        set(gca, 'XTick', vec, 'XTickLabel', ticks)
        set(gca, 'fontSize', 10)
        title(['TDCP Number of Satellites: ' char2gnss(sys)])
        xlabel('Time [hh:mm]')
        ylabel('# Satellites')
        xlim([min(x(x~=0)) max(x(x~=0))])
        ylim([0, max(n_sats, [], 'omitnan') + 2])
    end

    set(findall(gcf,'type','text'),'fontSize',8)
end


% Plot-Function for per-satellite residuals
function [] = plotit(x, tdcp_v, threshold, sigma0_threshold, vec, ticks, txt, sys, resets)
% create loop index
if sys == 'G'           % GPS
    loop = 1:99;
    col = DEF.COLOR_G;
elseif sys == 'R'       % GLONASS
    loop = 101:199;
    col = DEF.COLOR_R;
elseif sys == 'E'       % Galileo
    loop = 201:299;
    col = DEF.COLOR_E;
elseif sys == 'C'       % BeiDou
    loop = 301:399;
    col = DEF.COLOR_C;
elseif sys == 'J'       % QZSS
    loop = 401:410;
    col = DEF.COLOR_J;
end

%% plot the satellites
figur = figure('Name', ['Cycle Slip Detection with TDCP: ' char2gnss(sys)], ...
    'units','normalized', 'outerposition',[0 0 1 1], 'NumberTitle','off');
ii = 1;     % counter of subplot number
% add customized datatip
dcm = datacursormode(figur);
datacursormode on
set(dcm, 'updatefcn', @vis_customdatatip_CycleSlip)

for i = loop       % loop over satellites
    % Plotting
    y = tdcp_v(:,i);                % data of current satellite
    if any(~isnan(y) & y~=0)
        if ii == 17
            set(findall(gcf,'type','text'),'fontSize',8)
            % 16 satellites have been plotted in this window -> it is full
            % -> create new figure
            figur = figure('Name', ['Cycle Slip Detection with TDCP: ' char2gnss(sys)], ...
                'units','normalized', 'outerposition',[0 0 1 1], 'NumberTitle','off');
            ii = 1;     % counter of subplot number
            dcm = datacursormode(figur);
            datacursormode on
            set(dcm, 'updatefcn', @vis_customdatatip_CycleSlip)
        end
        y(y==0) = NaN;
        cs_idx = (abs(y) > threshold);   	% indices where TDCP residual exceeds threshold
        x_cs = x(cs_idx); y_cs = y(cs_idx);     % get cycle slip data
        prn = mod(i,100);           % satellite prn
        subplot(4, 4, ii)
        ii = ii + 1;  	% increase counter of plot number
        plot(x, y, '.', 'Color', col)
        hold on
        plot(x_cs,  y_cs,  'ko')	% highlight cycle-slips
        hline( threshold, 'g--')        % plot positive threshold
        hline(-threshold, 'g--')        % plot negative threshold
        % find those CS which are outside zoom
        idx = abs(y_cs) > 2*threshold;
        y_out = sign(y_cs(idx)) * 2*threshold;
        plot(x_cs(idx),  y_out,  'ro', 'MarkerSize',8)        % highlight CS outside of zoom window
        hold off
        % Styling
        grid off
        set(gca, 'XTick',vec, 'XTickLabel',ticks)
        set(gca, 'fontSize',8)
        title([txt, sprintf('%02d',prn), ': TDCP residual'])
        xlabel('Time [hh:mm]')
        ylabel('[m]')
        xlim([min(x(x~=0)) max(x(x~=0))])           % set x-axis
        ylim([-2*threshold, 2*threshold])            % set y-axis (symmetric)
    end
end
set(findall(gcf,'type','text'),'fontSize',8)
