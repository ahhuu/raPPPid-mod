function [] = vis_cs_MWGF(storeData, sys, tresh_hmw, fac_hmw, tresh_gf, Elev)
% Plots the combined MW+GF cycle slip detection results
% Left Axis: HMW LC (cycles)
% Right Axis: GF (dL1-dL2) (meters)
% 
% INPUT:
%   storeData       struct, collected data from all processed epochs
%   sys             1-digit-char which represents GNSS (G=GPS, R=GLONASS, ...)
%   tresh_hmw       threshold for HMW [cy]
%   fac_hmw         variance factor for HMW
%   tresh_gf        threshold for GF [m]
%   Elev            elevation of satellites
%
% This function belongs to raPPPid
% *************************************************************************

% time calculations
reset_sow = storeData.gpstime(storeData.float_reset_epochs);
duration = (storeData.gpstime(end) - storeData.gpstime(1))/3600; 

% create ticks
[vec, ticks] = duration2ticks(duration);
vec = storeData.gpstime(1) + vec;

% check if data exists
if ~isfield(storeData, 'cs_WL_12_diff') || ~isfield(storeData, 'cs_dL1dL2')
    errordlg('Required data for MWGF plot is missing. Please re-run the processing to collect MW and GF signals.', 'Plotting Error');
    return
end

% plot the combination
plotit(storeData, tresh_hmw, fac_hmw, tresh_gf, vec, ticks, sys, Elev, mod(reset_sow,86400))

function [] = plotit(storeData, thresh_hmw, fac_hmw, thresh_gf, vec, ticks, sys, Elev, resets)
% create loop index based on GNSS
if sys(end) == 'G'; loop = 1:99;  col = [0 0.4470 0.7410]; % GPS
elseif sys(end) == 'R'; loop = 101:199; col = [0.8500 0.3250 0.0980]; % GLO
elseif sys(end) == 'E'; loop = 201:299; col = [0.9290 0.6940 0.1250]; % GAL
elseif sys(end) == 'C'; loop = 301:399; col = [0.4940 0.1840 0.5560]; % BDS
elseif sys(end) == 'J'; loop = 401:410; col = [0.4660 0.6740 0.1880]; % QZSS
end

time = storeData.gpstime;
fig_name = ['MWGF Combined CS Detection: ' char2gnss(sys)];
fig1 = figure('Name', fig_name, 'units','normalized', 'outerposition',[0 0 1 1], 'NumberTitle','off');
ii = 1;

for i = loop
    % Get data
    hmw_diff = full(storeData.cs_WL_12_diff(:,i));
    gf_diff  = full(storeData.cs_dL1dL2(:,i));
    
    if any(hmw_diff ~= 0) || any(gf_diff ~= 0)
        % Create new figure if current one is full (8 satellites per fig for clarity)
        if ii == 9
            set(findall(gcf,'type','text'),'fontSize',8)
            fig1 = figure('Name', fig_name, 'units','normalized', 'outerposition',[0 0 1 1], 'NumberTitle','off');
            ii = 1;
        end
        
        subplot(4, 2, ii)
        ii = ii + 1;
        
        % Left Axis: HMW
        yyaxis left
        hmw_var = full(storeData.cs_var_12(:,i));
        thresh_mw = fac_hmw * sqrt(hmw_var);
        thresh_mw(thresh_mw > thresh_hmw) = thresh_hmw;
        thresh_mw(thresh_mw == 0) = NaN;
        hmw_diff(hmw_diff == 0) = NaN;
        
        plot(time, hmw_diff, '.', 'MarkerSize', 4)
        hold on
        plot(time, thresh_mw, 'b--', 'LineWidth', 0.5)
        ylabel('HMW [cy]')
        ax = gca; ax.YColor = [0 0.4470 0.7410];
        
        % Right Axis: GF
        yyaxis right
        gf_diff(gf_diff == 0) = NaN;
        el = full(Elev(:,i));
        gf_diff(el == 0) = NaN;
        
        plot(time, gf_diff, '.', 'MarkerSize', 4)
        plot(time,  thresh_gf*ones(size(time)), 'r--', 'LineWidth', 0.5)
        plot(time, -thresh_gf*ones(size(time)), 'r--', 'LineWidth', 0.5)
        ylabel('GF [m]')
        ax.YColor = [0.8500 0.3250 0.0980];
        
        % Highlight Combined Result
        cs_combined = full(storeData.cs_found(:,i));
        cs_idx = cs_combined > 0;
        if any(cs_idx)
            % Highlight on the active axis (right) or specifically
            plot(time(cs_idx), gf_diff(cs_idx), 'ko', 'MarkerSize', 8, 'LineWidth', 1.5)
            % Also plot on left if we want, but MATLAB markers apply to points.
            % We just use a black circle to indicate "Combined Decision Triggered"
        end
        
        % Styling
        grid on
        set(gca, 'XTick',vec, 'XTickLabel',ticks, 'fontSize',8)
        title([sys, sprintf('%02d',mod(i,100))])
        xlim([min(time(time~=0)) max(time(time~=0))])
        if ~isempty(resets); vline(resets, 'k:'); end
        hold off
    end
end
set(findall(gcf,'type','text'),'fontSize',8)
