function [] = createResidualsOutput(settings, storeData, satellites, epochs, outputPath, input)
% This function writes pseudorange residuals (float solution), elevation angles,
% and SNR information into a CSV file compatible with Python modeling scripts.
%
% INPUT:
%   settings    struct, processing settings
%   storeData   struct, processing results
%   satellites  struct, satellite-related data
%   epochs      vector, processed epochs
%   outputPath  string, filepath of the output CSV file
%   input       struct, input data including observation types (input.obs)
% OUTPUT:
%   []
%
% OUTPUT FORMAT (CSV):
%   epoch,prn,frequency,residual,snr,ele
%   1,G01,C1C,2.345678,38.5,45.2
%   1,G01,C5Q,-1.234567,36.2,45.2
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% Modified for Python compatibility, 2026
% *************************************************************************

% 获取处理的频率数量
n_freqs = settings.INPUT.proc_freqs;

% 打开文件以写入数据
fid = fopen(outputPath, 'w+');
if fid == -1
    error(['Failed to open file: ', outputPath]);
end

% 写入CSV表头
fprintf(fid, 'epoch,prn,frequency,residual,snr,ele\n');

% 获取有效卫星索引
obs_bool = logical(full(satellites.obs));
valid_sats = find(sum(obs_bool, 1) > 0);  % 至少有一个历元观测到的卫星
num_satellites = numel(valid_sats);
if num_satellites == 0
    fclose(fid);
    fprintf('Warning: No valid satellites found. Empty file created.\n');
    return;
end

% 获取总历元数
if isfield(storeData, 'residuals_code_1')
   total_epochs = size(storeData.residuals_code_1, 1);
   fprintf('Total epochs to process: %d\n', total_epochs);
else
   error('storeData has no residuals_code_1 field to determine total epochs');
end

% 遍历所有历元、卫星、频率（三层循环，长表格式）
for epoch_idx = 1:total_epochs
    for sat_idx = 1:num_satellites
        sat = valid_sats(sat_idx);
        
        % 将PRN转换为标准格式（G01, E05, C12等）
        if sat <= 99
            prn_str = sprintf('G%02d', sat);
        elseif sat >= 101 && sat <= 199
            prn_str = sprintf('R%02d', sat - 100);
        elseif sat >= 201 && sat <= 299
            prn_str = sprintf('E%02d', sat - 200);
        elseif sat >= 301 && sat <= 399
            prn_str = sprintf('C%02d', sat - 300);
        elseif sat >= 401 && sat <= 410
            prn_str = sprintf('J%02d', sat - 400);
        else
            prn_str = sprintf('X%02d', sat);  % 未知系统
        end
        
        % 获取当前历元当前卫星的高度角（所有频率共用）
        elev_angle = full(satellites.elev(epoch_idx, sat));
        
        % 遍历每个频率
        for freq_idx = 1:n_freqs
            % 获取伪距残差（浮点解）
            switch freq_idx
                case 1
                    code_residual = full(storeData.residuals_code_1(epoch_idx, sat));
                case 2
                    code_residual = full(storeData.residuals_code_2(epoch_idx, sat));
                case 3
                    code_residual = full(storeData.residuals_code_3(epoch_idx, sat));
                otherwise
                    code_residual = NaN;
            end
            
            % 获取信噪比
            snr_field = sprintf('SNR_%d', freq_idx);
            if isfield(satellites, snr_field)
                snr_value = full(satellites.(snr_field)(epoch_idx, sat));
            else
                snr_value = NaN;
            end
            
            % 获取频率标签（如 'C1C', 'C5Q'）- 从 settings 读取配置的频率
            freq_label = getFrequencyLabel(sat, freq_idx, settings);
            
            % 过滤无效数据：
            % 1. 频率为OFF（RINEX中无此频率数据）跳过
            if strcmpi(freq_label, 'OFF') || strcmpi(freq_label, 'UNKNOWN')
                continue;  % 跳过此频率
            end
            
            % 2. SNR为NaN（信噪比无效）跳过
            if isnan(snr_value)
                continue;
            end
            
            % 3. 残差为0或NaN（观测未参与PPP计算或被剔除）跳过
            % 这是最关键的过滤条件！
            if isnan(code_residual) || code_residual == 0
                continue;
            end
            
            % 所有检查通过，输出数据
            fprintf(fid, '%d,%s,%s,%.6f,%.6f,%.6f\n', ...
                epoch_idx, prn_str, freq_label, ...
                code_residual, snr_value, elev_angle);
        end
    end
end

% 关闭文件
fclose(fid);
fprintf('✓ Residuals CSV file written to: %s\n', outputPath);
fprintf('  Format: epoch,prn,frequency,residual,snr,ele\n');
fprintf('  Total epochs: %d, Total satellites: %d, Frequencies: %d\n', ...
    total_epochs, num_satellites, n_freqs);
end
