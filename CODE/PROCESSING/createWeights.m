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
    % observations on different frequencies get same weight factor
    P_diag(:,:) = settings.ADJ.elev_weight_fun(elev_n);       
    
    
    % --- No weighting of the observations
elseif settings.ADJ.weight_none
    P_diag(:,:) = 1;
    
    
% --- Weighting using signal to noise ratio (e.g., low-cost equipment), check [05]
elseif settings.ADJ.weight_sign_str
    
    if ischar(settings.ADJ.snr_weight_fun)
        % 固定SNR加权（内置选项）的原有逻辑
        switch settings.ADJ.snr_weight_fun
            case 'option_1'
                if ~isempty(Epoch.S1)
                    P_diag = goGPS_SNR_weighting(P_diag, Epoch.S1, 1);
                end
                if ~isempty(Epoch.S2) && settings.INPUT.proc_freqs >= 2
                    P_diag = goGPS_SNR_weighting(P_diag, Epoch.S2, 2);
                end
                if ~isempty(Epoch.S3) && settings.INPUT.proc_freqs >= 3
                    P_diag = goGPS_SNR_weighting(P_diag, Epoch.S3, 3);
                end
        end
        
    else
        % 自定义SNR加权（按不同系统与频点分别计算）
        SNR = [Epoch.S1, Epoch.S2, Epoch.S3];
        
        % 打印提示信息
        fprintf('\n--- SNR权重计算配置信息 ---\n');
        fprintf('卫星PRN | 系统 | 频点 | SNR值 | 权重公式 | 权重值\n');
        fprintf('-----------------------------------------------\n');
        
        % 遍历每颗卫星
        for i = 1:n_sats
            prn = Epoch.sats(i); % 读取当前PRN
            
            % 根据索引判断GNSS系统
            isGPS = ismember(i, find(Epoch.gps));
            isGLO = ismember(i, find(Epoch.glo));
            isGAL = ismember(i, find(Epoch.gal));
            isBDS = ismember(i, find(Epoch.bds));
            
            % 确定系统名称
            if isGPS
                sys = 'GPS';
            elseif isGLO
                sys = 'GLO';
            elseif isGAL
                sys = 'GAL';
            elseif isBDS
                sys = 'BDS';
            else
                sys = 'UNKN';
            end
            
            % 应用对应的SNR加权公式
            if isGPS % GPS系统
                if num_freq >= 1 % L1频点
                    freq_name = 'L1';
                    formula = '-0.8.*SNR+37';
                    P_diag(i,1) = -0.8.*SNR(i,1)+37;
                    fprintf('%6d | %4s | %3s | %5.1f | %s | %.4f\n', ...
                            prn, sys, freq_name, SNR(i,1), formula, P_diag(i,1));
                end
                if num_freq >= 2 % L5频点
                    freq_name = 'L5';
                    formula = '-0.8.*SNR+37';
                    P_diag(i,2) = -0.8.*SNR(i,2)+37;
                    fprintf('%6d | %4s | %3s | %5.1f | %s | %.4f\n', ...
                            prn, sys, freq_name, SNR(i,2), formula, P_diag(i,2));
                end
                
            elseif isGAL % Galileo系统
                if num_freq >= 1 % E1频点
                    freq_name = 'E1';
                    formula = '-0.8.*SNR+37';
                    P_diag(i,1) = -0.8.*SNR(i,1)+37;
                    fprintf('%6d | %4s | %3s | %5.1f | %s | %.4f\n', ...
                            prn, sys, freq_name, SNR(i,1), formula, P_diag(i,1));
                end
                if num_freq >= 2 % E5a频点
                    freq_name = 'E5a';
                    formula = '-0.8.*SNR+37';
                    P_diag(i,2) = -0.8.*SNR(i,2)+37;
                    fprintf('%6d | %4s | %3s | %5.1f | %s | %.4f\n', ...
                            prn, sys, freq_name, SNR(i,2), formula, P_diag(i,2));
                end
                if num_freq >= 3 % E5b频点
                    freq_name = 'E5b';
                    formula = '-0.8.*SNR+37';
                    P_diag(i,3) = -0.8.*SNR(i,3)+37;
                    fprintf('%6d | %4s | %3s | %5.1f | %s | %.4f\n', ...
                            prn, sys, freq_name, SNR(i,3), formula, P_diag(i,3));
                end
                
            elseif isGLO % GLONASS系统
                if num_freq >= 1 % R1频点
                    freq_name = 'R1';
                    formula = '-0.8.*SNR+37';
                    P_diag(i,1) = -0.8.*SNR(i,1)+37;
                    fprintf('%6d | %4s | %3s | %5.1f | %s | %.4f\n', ...
                            prn, sys, freq_name, SNR(i,1), formula, P_diag(i,1));
                end
                
            elseif isBDS % BDS系统
                if num_freq >= 1 % B1频点
                    freq_name = 'B1';
                    formula = '-0.8.*SNR+37';
                    P_diag(i,1) = -0.8.*SNR(i,1)+37;
                    fprintf('%6d | %4s | %3s | %5.1f | %s | %.4f\n', ...
                            prn, sys, freq_name, SNR(i,1), formula, P_diag(i,1));
                end
                if num_freq >= 2 % B1AC频点
                    freq_name = 'B1AC';
                    formula = '-0.8.*SNR+37';
                    P_diag(i,2) = -0.8.*SNR(i,2)+37;
                    fprintf('%6d | %4s | %3s | %5.1f | %s | %.4f\n', ...
                            prn, sys, freq_name, SNR(i,2), formula, P_diag(i,2));
                end
                if num_freq >= 3 % B2a频点
                    freq_name = 'B2a';
                    formula = '-0.8.*SNR+37';
                    P_diag(i,3) = -0.8.*SNR(i,3)+37;
                    fprintf('%6d | %4s | %3s | %5.1f | %s | %.4f\n', ...
                            prn, sys, freq_name, SNR(i,3), formula, P_diag(i,3));
                end
            end
        end
        
        % 处理缺失值（延续原有逻辑）
        if settings.INPUT.proc_freqs >= 2 
            % 用一频权重补二频缺失值
            replace_idx = isnan(P_diag(:,2)) | P_diag(:,2) == 0;
            if any(replace_idx)
                fprintf('\n二频缺失值：用频点1替代频点2，影响%d颗卫星。\n', sum(replace_idx));
                P_diag(replace_idx,2) = P_diag(replace_idx,1);
            end
        end
        if settings.INPUT.proc_freqs >= 3
            % 用一频权重补三频缺失值
            replace_idx = isnan(P_diag(:,3)) | P_diag(:,3) == 0;
            if any(replace_idx)
                fprintf('三频缺失值：用频点1替代频点3，影响%d颗卫星。\n', sum(replace_idx));
                P_diag(replace_idx,3) = P_diag(replace_idx,1);
            end
        end
        
        fprintf('\n权重矩阵前5行预览：\n');
        disp(P_diag(1:min(5,size(P_diag,1)),:));
    end

% --- Weighting depending on a combination of SNR and elevation
elseif settings.ADJ.weight_snr_elev
    SNR = [Epoch.S1, Epoch.S2, Epoch.S3];
    
    % 若权重函数包含 max()/min()/sin() 等需要标量输入的函数
    if contains(func2str(settings.ADJ.snr_elev_weight_fun), {'max(', 'min(', 'sin('})
        % 按元素计算权重，逐个调用函数
        for i = 1:n_sats
            for j = 1:num_freq
                if isnan(SNR(i,j)) || isnan(elev_n(i,j))
                    P_diag(i,j) = 1e-6;  % 缺失值给极小权重
                else
                    % 计算权重：使用给定模型，比较SNR与高度角
                    w = settings.ADJ.snr_elev_weight_fun(SNR(i,j), elev_n(i,j));
                    
                    % 限制权重范围，避免极端值
                    P_diag(i,j) = max(min(w, 1e6), 1e-6);
                end
            end
        end
    else
        % 向量化计算权重：适合简单函数
        % 预构造SNR与高度角矩阵
        SNR_matrix = SNR;
        elev_matrix = repmat(elev_n, 1, num_freq);
        
        % 批量计算权重
        P_diag = settings.ADJ.snr_elev_weight_fun(SNR_matrix, elev_matrix);
        
        % 处理缺失/无效值
        for j = 1:num_freq
            invalid_idx = isnan(SNR(:,j)) | isnan(elev_n(:,j));
            P_diag(invalid_idx,j) = 1e-6;
            
            % 限制权重范围
            P_diag(:,j) = max(min(P_diag(:,j), 1e6), 1e-6);
        end
        
        % 频点补全：某频缺失时使用一频的权重
        if settings.INPUT.proc_freqs >= 2
            % 取一频补二频
            P_diag_1 = P_diag(:,1);
            P_diag_2 = P_diag(:,2);
            bool = isnan(P_diag_2) | P_diag_2 == 0;
            P_diag_2(bool) = P_diag_1(bool);
            P_diag(:,2) = P_diag_2;
        end
        
        if settings.INPUT.proc_freqs >= 3
            % 取一频补三频
            P_diag_3 = P_diag(:,3);
            bool = isnan(P_diag_3) | P_diag_3 == 0;
            P_diag_3(bool) = P_diag_1(bool);
            P_diag(:,3) = P_diag_3;
        end
    end
end

% --- GNSS weighting
P_diag(Epoch.gps,:) = P_diag(Epoch.gps,:) / settings.ADJ.fac_GPS;
P_diag(Epoch.glo,:) = P_diag(Epoch.glo,:) / settings.ADJ.fac_GLO;
P_diag(Epoch.gal,:) = P_diag(Epoch.gal,:) / settings.ADJ.fac_GAL;
P_diag(Epoch.bds,:) = P_diag(Epoch.bds,:) / settings.ADJ.fac_BDS;

% very low weigth for weights which are NaN, zero, or negative
P_diag(isnan(P_diag)) = 10^-6;      
P_diag(P_diag <= 0) = 10^-6; 

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