function [] = createResidualsOutput(settings, storeData, satellites, epochs, outputPath)
% This function writes pseudorange residuals, elevation angles, and SNR information
% into a text file.
%
% INPUT:
%   settings    struct, processing settings
%   storeData   struct, processing results
%   satellites  struct, satellite-related data
%   epochs      vector, processed epochs
%   outputPath  string, filepath of the output file to write
% OUTPUT:
%   []
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

% 获取处理的频率数量
n = settings.INPUT.proc_freqs;

% 打开文件以写入数据
fid = fopen(outputPath, 'w+');
if fid == -1
    error(['Failed to open file: ', outputPath]);
end

% 写入文件头部信息
fprintf(fid, '# This file contains pseudorange residuals, elevation angles, and SNR information.\n');
fprintf(fid, '# Columns:\n');
fprintf(fid, '# (1) Epoch number []\n');
fprintf(fid, '# (2) Satellite PRN []\n');
for j = 1:n
    fprintf(fid, '# (%d) Pseudorange residual [m] (Frequency %d)\n', 3 + 3 * (j - 1), j);
    fprintf(fid, '# (%d) Elevation angle [°] (Frequency %d)\n', 4 + 3 * (j - 1), j);
    fprintf(fid, '# (%d) SNR [dB-Hz] (Frequency %d)\n', 5 + 3 * (j - 1), j);
end
fprintf(fid, '#************************************************** \n');

% 获取有效卫星索引
obs_bool = logical(full(satellites.obs));
valid_sats = find(sum(obs_bool, 1) > 0);  % 至少有一个历元观测到的卫星
num_satellites = numel(valid_sats);
if num_satellites == 0
    fclose(fid);
    return;
end

% 强制使用数据总长度作为历元数量，覆盖输入的epochs
% 从数据中获取实际总历元数（假设与storeData的第一维度一致）
if isfield(storeData, 'residuals_code_1')
   total_epochs = size(storeData.residuals_code_1, 1);  % 数据的总行数即总历元数
   epochs = 1:total_epochs;  % 生成完整的历元序列（1到total_epochs）
   fprintf('Updated epochs to full range: 1 to %d\n', total_epochs);
else
   error('storeData has no residuals_code_1 field to determine total epochs');
end

% 遍历所有历元（直接使用历元号）
fprintf('Total epochs to process: %d\n', length(epochs));
for epoch_idx = epochs
    q = find(epochs == epoch_idx, 1);
    if isempty(q)
        fprintf('Warning: Epoch %d not found in epochs array\n', epoch_idx);
        continue;
    end
    
    % 遍历有效卫星
    for sat_idx = 1:num_satellites
        sat = valid_sats(sat_idx);
        
        % 初始化标志（仅跳过全NaN的行，保留0值）
        all_nan = true;
        line_data = [];
        
        % 遍历每个频率
        for j = 1:n
            % 获取伪距残差
            if settings.PLOT.float
                code_residual = full(storeData.residuals_code_1(q, sat));
                if n > 1 && j == 2, code_residual = full(storeData.residuals_code_2(q, sat)); end
                if n > 2 && j == 3, code_residual = full(storeData.residuals_code_3(q, sat)); end
            else
                code_residual = full(storeData.residuals_code_fix_1(q, sat));
                if n > 1 && j == 2, code_residual = full(storeData.residuals_code_fix_2(q, sat)); end
                if n > 2 && j == 3, code_residual = full(storeData.residuals_code_fix_3(q, sat)); end
            end
            
            % 获取高度角
            elev_angle = full(satellites.elev(q, sat));
            
            % 获取信噪比
            field = sprintf('SNR_%d', j);
            SNR = full(satellites.(field)(q, sat));
            
            % 存储数据并检查有效性（0值视为有效残差，仅过滤全NaN）
            line_data = [line_data, code_residual, elev_angle, SNR];
            if ~isnan(code_residual) || ~isnan(elev_angle) || ~isnan(SNR)
                all_nan = false;
            end
        end
        
        % 写入非全NaN的行
        if ~all_nan
            fprintf(fid, '%4.0f  %4.0f  ', epoch_idx, sat);
            for i = 1:length(line_data)
                fprintf(fid, '%14.6f  ', line_data(i));
            end
            fprintf(fid, '\n');
        end
    end
end

% 关闭文件
fclose(fid);
fprintf('Residuals file written to: %s\n', outputPath);
end

