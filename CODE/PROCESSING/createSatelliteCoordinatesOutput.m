function [] = createSatelliteCoordinatesOutput(Epoch, input, settings, model)
% This function writes satellite coordinates to a file in the processing output folder.
% This function is called ONCE PER EPOCH during PPP processing and appends data to the file.
%
% INPUT:
%   Epoch           struct, contains data for ONE epoch
%   input           struct, input data for processing
%   settings        struct, settings for processing from GUI
%   model           struct, model data including precise Ttr values
% OUTPUT:
%   []
%
% OUTPUT FORMAT:
%   #Epoch    PRN   Ttr             X                   Y                   Z
%   1         1     403200.000000   -15347892.123456    -20427134.567890    11364512.345678
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% Modified for incremental writing and precise Ttr, 2026
% *************************************************************************

    persistent epoch_counter;
    persistent output_file_path;
    persistent prev_file_name;

    % 检查输出目录是否存在，若不存在则创建
    output_dir = settings.PROC.output_dir;
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % 输出文件路径
    outputFileName = fullfile(output_dir, 'satellite_positions.txt');
    
    % 检测是否开始处理新文件（通过比较输出目录路径）
    % 使用输出目录而非文件名，因为同一个RINEX文件可能多次处理到不同目录
    current_output_path = output_dir;
    if isempty(prev_file_name) || ~strcmp(current_output_path, prev_file_name)
        % 新处理：重置计数器并创建新文件（覆盖模式）
        epoch_counter = 1;
        prev_file_name = current_output_path;  % 保存输出目录而非文件名
        output_file_path = outputFileName;
        
        % 写入文件头
        fid = fopen(outputFileName, 'w');
        if fid == -1
            error('无法打开文件 %s 进行写入。', outputFileName);
        end
        fprintf(fid, '#%-10s\t%-4s\t%-12s\t%24s  %24s  %24s\n', ...
                'Epoch', 'PRN', 'Ttr', 'X', 'Y', 'Z');
        fclose(fid);
    else
        % 同一处理：递增历元计数器
        epoch_counter = epoch_counter + 1;
    end

    % 检查当前历元是否有卫星数据
    if ~isfield(Epoch, 'sats') || isempty(Epoch.sats)
        return;  % 无卫星数据，直接返回
    end
    
    % 当前历元的观测时间（GPS时间）
    gps_time = Epoch.gps_time;
    
    n = numel(Epoch.sats);    % 当前历元的卫星数量
    X = zeros(3, n);          % 存储卫星坐标
    V = zeros(3, n);          % 存储卫星速度
    Ttr_all = zeros(1, n);    % 存储每颗卫星的信号发射时间
    exclude = false(1, n);    % 存储卫星是否排除的标志
    status = zeros(1, n);     % 存储卫星状态

    % 计算当前历元所有卫星的坐标
    for i = 1:n
        prn = Epoch.sats(i);
        isGPS = Epoch.gps(i);
        isGLO = Epoch.glo(i);
        isGAL = Epoch.gal(i);
        isBDS = Epoch.bds(i);
        isQZSS = Epoch.qzss(i);
        
        % 获取广播星历索引
        if settings.ORBCLK.bool_brdc && isfield(Epoch, 'BRDCcolumn')
            k = Epoch.BRDCcolumn(prn);
        else
            k = NaN;
        end
        
        % 从 model.Ttr 获取精确的信号发射时间
        % model.Ttr(卫星索引, 频率索引) - 使用第一个频率的值
        if isfield(model, 'Ttr') && size(model.Ttr, 1) >= i && size(model.Ttr, 2) >= 1
            Ttr = model.Ttr(i, 1);  % 使用第一个频率的精确Ttr
        else
            % 备用方案：简化计算（理论上不应该执行到这里）
            code_obs = Epoch.code(i);
            if ~isnan(code_obs) && code_obs > 0
                tau = code_obs / Const.C;
                Ttr = gps_time - tau;
            else
                tau = 20000000 / Const.C;
                Ttr = gps_time - tau;
            end
        end
        Ttr_all(i) = Ttr;

        % 获取轨道改正参数
        if isfield(Epoch, 'corr2brdc_orb') && size(Epoch.corr2brdc_orb, 2) >= prn
            corr_orb = Epoch.corr2brdc_orb(:, prn);
        else
            corr_orb = zeros(7, 1);  % 如果没有改正参数，使用零向量
        end

        % 计算卫星坐标
        [X(:, i), V(:, i), exclude(i), status(i)] = satelliteOrbit(prn, Ttr, input, ...
            isGPS, isGLO, isGAL, isBDS, isQZSS, k, settings, exclude(i), status(i), corr_orb);
    end
    
    % 追加写入文件
    fid = fopen(outputFileName, 'a');
    if fid == -1
        error('无法打开文件 %s 进行追加。', outputFileName);
    end
    
    % 写入当前历元的所有卫星坐标（使用各自的Ttr）
    for i = 1:n
        if ~exclude(i)
            prn = Epoch.sats(i);
            fprintf(fid, '%-11d\t%-4d\t%-12.6f\t%24.6f  %24.6f  %24.6f\n', ...
                epoch_counter, prn, Ttr_all(i), X(1, i), X(2, i), X(3, i));
        end
    end
    
    fclose(fid);
end