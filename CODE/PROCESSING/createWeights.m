function P_diag = createWeights(Epoch, elev, settings)
% Function to create the weights of the observations for the diagonal of 
% the weighting matrix P or, in other words, the weight factors for the
% variance of the observations.
% Variants:
% -) weight the observations depending on the procedure described in [02]
% -) weight the observations depending on the elevation of their satellites
% -) weight the observations depending on their signal strength on 1st frequency
% -) weight the observations depending on a combination of SNR and elevation
% 
% INPUT:
%   Epoch           containing epoch-specific data
%   elev            elevation of the satellites of current epoch [度]
%   settings        setting of proceesing from GUI
% OUTPUT:
%   P_diag          [n sats x input freqs], weight for each satellite and frequency
% 
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

% 声明persistent变量（必须在函数开头）
persistent bds_orbit_diagnostic_data diagnostic_printed;

num_freq = settings.INPUT.num_freqs;        % number of input frequencies
n_sats = numel(Epoch.sats);                 % # sats in current epoch
P_diag = ones(n_sats,num_freq);
elev = elev*pi/180; 	% elevation of satellites of this epoch [rad]
elev_n = repmat(elev(:,1),1,num_freq);      % elevation is equal on all frequencies

% --- Weighting depending on combination of elevation and MP-LC, check [02]
if settings.ADJ.weight_mplc
    if Epoch.q > 5
        w1 = tanh((Epoch.mp1_var.^-1)/100)' + sin(elev);
        w2 = tanh((Epoch.mp2_var.^-1)/100)' + sin(elev);
        w = (w1+w2)/2;
        % variance = NaN (e.g. satellite is not observed for 5 epochs),
        % weight according to sqrt(elevation)
        w(isnan(w)) = sqrt(elev(isnan(w)));
        P_diag(:,1) = w;
        P_diag(:,2) = w;
    else        % not enough epochs to calculate variance so weight depending on elevation
        P_diag = sin(elev_n).^2;
    end
    
    
    % --- Weighting according to elevation
elseif settings.ADJ.weight_elev
    % observations on different frequencies get weight factor
    for i = 1:n_sats
        funs = getFunctionsForSat(i, Epoch, settings.ADJ.elev_weight_fun);
        for j = 1:num_freq
            fun = funs{mod(j-1, numel(funs))+1};
            P_diag(i,j) = fun(elev_n(i,j));
        end
    end
    
    
    % --- No weighting of the observations
elseif settings.ADJ.weight_none
    P_diag(:,:) = 1;
    
    
% --- Weighting using signal to noise ratio (e.g., low-cost equipment), check [05]
elseif settings.ADJ.weight_sign_str
    SNR = [Epoch.S1, Epoch.S2, Epoch.S3];
    
    for i = 1:n_sats
        funs = getFunctionsForSat(i, Epoch, settings.ADJ.snr_weight_fun);
        for j = 1:num_freq
            fun = funs{mod(j-1, numel(funs))+1};
            if ischar(fun) && contains(fun, 'option')
                % 处理单元格内的硬编码选项
                P_row = goGPS_SNR_weighting(zeros(1,num_freq), SNR(i,j), j);
                P_diag(i,j) = P_row(j);
            else
                % 处理函数句柄
                P_diag(i,j) = fun(SNR(i,j));
            end
        end
    end
    
    % 处理缺失及范围限制
    for j = 1:num_freq
        invalid_idx = isnan(SNR(:,j)) | P_diag(:,j) <= 0;
        P_diag(invalid_idx,j) = 1e-6;
        P_diag(:,j) = max(min(P_diag(:,j), 1e6), 1e-6);
    end
    
    % 频点补全逻辑
    if settings.INPUT.proc_freqs >= 2
        replace_idx = isnan(SNR(:,2)) | P_diag(:,2) <= 1e-6;
        P_diag(replace_idx,2) = P_diag(replace_idx,1);
    end
    if settings.INPUT.proc_freqs >= 3
        replace_idx = isnan(SNR(:,3)) | P_diag(:,3) <= 1e-6;
        P_diag(replace_idx,3) = P_diag(replace_idx,1);
    end

% --- Weighting depending on a combination of SNR and elevation
elseif settings.ADJ.weight_snr_elev
    SNR = [Epoch.S1, Epoch.S2, Epoch.S3];
    
    for i = 1:n_sats
        funs = getFunctionsForSat(i, Epoch, settings.ADJ.snr_elev_weight_fun);
        for j = 1:num_freq
            fun = funs{mod(j-1, numel(funs))+1};
            P_diag(i,j) = calculateCombinedWeight(fun, SNR(i,j), elev_n(i,j));
        end
    end
    
    % 处理缺失及范围限制
    for j = 1:num_freq
        invalid_idx = isnan(SNR(:,j)) | isnan(elev_n(:,j)) | P_diag(:,j) <= 0;
        P_diag(invalid_idx,j) = 1e-6;
        P_diag(:,j) = max(min(P_diag(:,j), 1e6), 1e-6);
    end

    % 频点补全
    if settings.INPUT.proc_freqs >= 2
        replace_idx = isnan(SNR(:,2)) | P_diag(:,2) <= 1e-6;
        P_diag(replace_idx,2) = P_diag(replace_idx,1);
    end
    if settings.INPUT.proc_freqs >= 3
        replace_idx = isnan(SNR(:,3)) | P_diag(:,3) <= 1e-6;
        P_diag(replace_idx,3) = P_diag(replace_idx,1);
    end
end

% --- GNSS weighting
P_diag(Epoch.gps,:) = P_diag(Epoch.gps,:) / settings.ADJ.fac_GPS;
P_diag(Epoch.glo,:) = P_diag(Epoch.glo,:) / settings.ADJ.fac_GLO;
P_diag(Epoch.gal,:) = P_diag(Epoch.gal,:) / settings.ADJ.fac_GAL;
P_diag(Epoch.bds,:) = P_diag(Epoch.bds,:) / settings.ADJ.fac_BDS;

% --- BDS Orbit-Specific Weighting (轨道分层定权)
if isfield(settings.ADJ, 'bds_orbit_weighting') && settings.ADJ.bds_orbit_weighting && any(Epoch.bds)
    bds_sats = Epoch.sats(Epoch.bds);  % 提取BDS卫星PRN号 (raPPPid中BDS范围为301-363)
    bds_prn_only = mod(bds_sats, 100); % 提取原始PRN (e.g., 303 -> 3)
    
    % 识别轨道类型
    is_geo  = ismember(bds_prn_only, [1:5, 59:62]);    % C01-C05 (BDS-2) + C59-C62 (BDS-3)
    is_igso = ismember(bds_prn_only, [6:10, 13, 16, 38:40]);  % BDS-2/3 IGSO
    is_meo  = ~is_geo & ~is_igso;  % 其余为MEO (C11-C12, C14, C19-C37, C41-C46等)
    
    % 设置轨道权重因子
    orbit_factor = ones(sum(Epoch.bds), num_freq);
    orbit_factor(is_geo, :)  = settings.ADJ.bds_geo_factor;   % GEO降权（默认0.3）
    orbit_factor(is_igso, :) = settings.ADJ.bds_igso_factor;  % IGSO标准权重（默认1.0）
    orbit_factor(is_meo, :)  = settings.ADJ.bds_meo_factor;   % MEO标准权重（默认1.0）
    
    % 应用轨道权重
    P_diag(Epoch.bds, :) = P_diag(Epoch.bds, :) .* orbit_factor;
    
    % 收集每个历元的BDS卫星信息（用于最后输出）
    if isempty(bds_orbit_diagnostic_data)
        bds_orbit_diagnostic_data.all_geo_sats = [];
        bds_orbit_diagnostic_data.all_igso_sats = [];
        bds_orbit_diagnostic_data.all_meo_sats = [];
    end
    bds_orbit_diagnostic_data.all_geo_sats = unique([bds_orbit_diagnostic_data.all_geo_sats; bds_sats(is_geo)]);
    bds_orbit_diagnostic_data.all_igso_sats = unique([bds_orbit_diagnostic_data.all_igso_sats; bds_sats(is_igso)]);
    bds_orbit_diagnostic_data.all_meo_sats = unique([bds_orbit_diagnostic_data.all_meo_sats; bds_sats(is_meo)]);
end

% very low weigth for weights which are NaN, zero, or negative
P_diag(isnan(P_diag)) = 10^-6;      
P_diag(P_diag <= 0) = 10^-6; 

% --- 终端诊断输出 (Diagnostic Output) ---
try
    % 在起始历元手动重置标志位
    if isfield(Epoch, 'q') && isfield(settings, 'PROC') && isfield(settings.PROC, 'epochs') && ...
       Epoch.q == settings.PROC.epochs(1); diagnostic_printed = false; end
    
    % 检测是否为最后一个历元 (settings.PROC.epochs(2) 是结束历元索引)
    if isfield(Epoch, 'q') && isfield(settings, 'PROC') && isfield(settings.PROC, 'epochs') && ...
       Epoch.q == settings.PROC.epochs(2) && (~diagnostic_printed)
        
        fprintf('\n%s [raPPPid] Final Weighting Configuration Summary %s\n', repmat('=',1,15), repmat('=',1,15));
        fprintf('%-8s | %-4s | %-6s | %-8s | %-30s | %-10s\n', 'Sat', 'Sys', 'Freq', 'Value', 'Formula', 'Weight');
        fprintf('%s\n', repmat('-', 85));
        
        for i = 1:n_sats
            prn = Epoch.sats(i);
            if Epoch.gps(i); sys = 'GPS'; elseif Epoch.glo(i); sys = 'GLO';
            elseif Epoch.gal(i); sys = 'GAL'; elseif Epoch.bds(i); sys = 'BDS';
            else; sys = 'OTHER'; end
            
            % 获取该卫星使用的函数组
            if settings.ADJ.weight_elev; fun_setting = settings.ADJ.elev_weight_fun;
            elseif settings.ADJ.weight_sign_str; fun_setting = settings.ADJ.snr_weight_fun;
            elseif settings.ADJ.weight_snr_elev; fun_setting = settings.ADJ.snr_elev_weight_fun;
            else; fun_setting = @(x) 1; end
            
            funs = getFunctionsForSat(i, Epoch, fun_setting);
            
            for j = 1:num_freq
                fun = funs{mod(j-1, numel(funs))+1};
                
                % 准备显示数据
                if settings.ADJ.weight_elev
                    val = elev(i,1)*180/pi; % 显示度数
                    val_str = sprintf('%.1f deg', val);
                elseif settings.ADJ.weight_sign_str
                    SNR_vals = [Epoch.S1, Epoch.S2, Epoch.S3];
                    val = SNR_vals(i,j);
                    val_str = sprintf('%.1f dBHz', val);
                elseif settings.ADJ.weight_snr_elev
                    SNR_vals = [Epoch.S1, Epoch.S2, Epoch.S3];
                    val_str = sprintf('S%.0f, E%.0f', SNR_vals(i,j), elev(i,1)*180/pi);
                else
                    val_str = 'N/A';
                end
                
                if ischar(fun); fun_str = fun; else; fun_str = func2str(fun); end
                
                fprintf('%-8d | %-4s | %-6d | %-8s | %-30s | %-10.4f\n', ...
                    prn, sys, j, val_str, fun_str, P_diag(i,j));
            end
        end
        fprintf('%s\n\n', repmat('=', 45));
        diagnostic_printed = true;
        
        % 输出BDS轨道权重诊断（在现有诊断之后）
        if isfield(settings.ADJ, 'bds_orbit_weighting') && settings.ADJ.bds_orbit_weighting
            if ~isempty(bds_orbit_diagnostic_data)
                fprintf('\n%s [BDS Orbit Weighting Summary] %s\n', repmat('=',1,12), repmat('=',1,12));
                fprintf('Weighting Factors: GEO=%.2f, IGSO=%.2f, MEO=%.2f\n', ...
                    settings.ADJ.bds_geo_factor, settings.ADJ.bds_igso_factor, settings.ADJ.bds_meo_factor);
                fprintf('Satellites observed during processing:\n');
                if ~isempty(bds_orbit_diagnostic_data.all_geo_sats)
                    fprintf('  GEO  (%2d sats): %s\n', length(bds_orbit_diagnostic_data.all_geo_sats), ...
                        mat2str(sort(bds_orbit_diagnostic_data.all_geo_sats)'));
                end
                if ~isempty(bds_orbit_diagnostic_data.all_igso_sats)
                    fprintf('  IGSO (%2d sats): %s\n', length(bds_orbit_diagnostic_data.all_igso_sats), ...
                        mat2str(sort(bds_orbit_diagnostic_data.all_igso_sats)'));
                end
                if ~isempty(bds_orbit_diagnostic_data.all_meo_sats)
                    fprintf('  MEO  (%2d sats): %s\n', length(bds_orbit_diagnostic_data.all_meo_sats), ...
                        mat2str(sort(bds_orbit_diagnostic_data.all_meo_sats)'));
                end
                fprintf('%s\n\n', repmat('=', 50));
            end
        end
    end
catch
    % 静默处理，避免核心计算中断
end

end



function w = calculateCombinedWeight(fun, SNR, elev)
% Helper to calculate weights supporting both vectorized and element-wise handles
try
    % Try vectorized first
    w = fun(SNR, elev);
catch
    % Fallback to element-wise if vectorized fails
    w = zeros(size(SNR));
    for i = 1:numel(SNR)
        w(i) = fun(SNR(i), elev(i));
    end
end
end



function funs = getFunctionsForSat(sat_idx, Epoch, fun_setting)
% Helper to fetch the correct weighting function for a specific satellite system
if isstruct(fun_setting)
    % Identify system
    if isfield(Epoch, 'gps') && Epoch.gps(sat_idx); sys = 'GPS';
    elseif isfield(Epoch, 'glo') && Epoch.glo(sat_idx); sys = 'GLO';
    elseif isfield(Epoch, 'gal') && Epoch.gal(sat_idx); sys = 'GAL';
    elseif isfield(Epoch, 'bds') && Epoch.bds(sat_idx); sys = 'BDS';
    elseif isfield(Epoch, 'qzss') && Epoch.qzss(sat_idx); sys = 'QZSS';
    else; sys = 'default'; end
    
    if isfield(fun_setting, sys)
        funs = fun_setting.(sys);
    elseif isfield(fun_setting, 'default')
        funs = fun_setting.default;
    else
        % Fallback to any available field if default is missing
        fields = fieldnames(fun_setting);
        funs = fun_setting.(fields{1});
    end
elseif iscell(fun_setting)
    funs = fun_setting;
else
    funs = {fun_setting};
end
end



function P_diag = goGPS_SNR_weighting(P_diag, SNR, frq)
% Creating weights depending on Carrier-to-Noise density following [05]: (5.1) 
% 
% INPUT:
%   P_diag      values for diagonal of weight matrix P
%   C/N0        Carrier-to-Noise Density of current frequency
%   frq         frequency or column of P_diag which should be manipulated
% OUTPUT:
%   P_diag      calculated weights added
% *************************************************************************

% some constants
a = 30;         % defines bending of the curve
s_1 = 50;       % C/N0 > this threshold, weight = 1
s_0 = 20;       % defines C/N0 where function is forced to have the weight defined by A
A = 30;     	% ... however, 1/is used here already
% calculate weights
q_R = 10.^(-(SNR-s_1)/a) .* ( (A/10.^(-(s_0-s_1)/a)-1)./(s_0-s_1).*(SNR-s_1)+1 );
P_diag(:,frq) = P_diag(:,frq) ./ q_R;        	% weight for observations
P_diag(SNR >= s_1, frq) = 1;                    % 1 for C/N0 > snr_1

end