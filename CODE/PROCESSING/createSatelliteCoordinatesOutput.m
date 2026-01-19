function [] = createSatelliteCoordinatesOutput(Epoch, input, settings)
% This function writes satellite coordinates to a file in the processing output folder.
%
% INPUT:
%   Epoch           struct array, each element contains data for one epoch
%   input           struct, input data for processing
%   settings        struct, settings for processing from GUI
% OUTPUT:
%   []
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

    % 检查输出目录是否存在，若不存在则创建
    output_dir = settings.PROC.output_dir;
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % 输出文件路径
    outputFileName = fullfile(output_dir, 'satellite_coordinates.txt');
    fid = fopen(outputFileName, 'w');
    if fid == -1
        error('无法打开文件 %s 进行写入。', outputFileName);
    end

    % 写入文件头
    fprintf(fid, '#Epoch_Time\t#PRN\t#Ttr\t#X\t#Y\t#Z\n');

    % 从 Epoch 结构体中获取所有历元的时间
    if isstruct(Epoch) && isfield(Epoch, 'gps_time')
        if isscalar(Epoch)
            % 如果 Epoch 是单个结构体（兼容旧版）
            total_epochs = 1;
            epochs = 1;
        else
            % 如果 Epoch 是结构体数组（每个元素是一个历元）
            total_epochs = length(Epoch);
            epochs = 1:total_epochs;
        end
    else
        error('Epoch 结构体格式不正确，缺少 gps_time 字段');
    end

    % 用于记录 Ttr 的计数
    epoch_time_counter = 1;
    % 用于记录上一个 Ttr 的值
    prev_Ttr = NaN;

    % 遍历所有历元
    fprintf('Total epochs to process: %d\n', total_epochs);
    for epoch_idx = epochs
        % 获取当前历元的数据
        current_epoch = Epoch(epoch_idx);
        
        % 检查当前历元是否有卫星数据
        if ~isfield(current_epoch, 'sats') || isempty(current_epoch.sats)
            fprintf('跳过第 %d 个历元，因为没有卫星数据。\n', epoch_idx);
            continue; % 跳过无卫星数据的历元
        end
        
        n = numel(current_epoch.sats);    % 当前历元的卫星数量
        X = zeros(3, n);                  % 存储卫星坐标
        V = zeros(3, n);                  % 存储卫星速度
        exclude = false(1, n);            % 存储卫星是否排除的标志
        status = zeros(1, n);             % 存储卫星状态
        corr_orb = zeros(7, 1);           % 假设 corr_orb 初始化为零向量

        % 计算当前历元所有卫星的坐标
        for i = 1:n
            prn = current_epoch.sats(i);
            isGPS = current_epoch.gps(i);
            isGLO = current_epoch.glo(i);
            isGAL = current_epoch.gal(i);
            isBDS = current_epoch.bds(i);
            isQZSS = current_epoch.qzss(i);
            
            % 获取广播星历索引
            if settings.ORBCLK.bool_brdc && isfield(current_epoch, 'BRDCcolumn')
                k = current_epoch.BRDCcolumn(prn);
            else
                k = NaN;
            end
            
            % 假设 Ttr 等于当前历元的 GPS 时间
            Ttr = current_epoch.gps_time; 

            % 计算卫星坐标（传入当前历元的时间）
            [X(:, i), V(:, i), exclude(i), status(i)] = satelliteOrbit(prn, Ttr, input, ...
                isGPS, isGLO, isGAL, isBDS, isQZSS, k, settings, exclude(i), status(i), corr_orb);

            % 检查 Ttr 是否变化
            if ~isnan(prev_Ttr) && Ttr ~= prev_Ttr
                epoch_time_counter = epoch_time_counter + 1;
            end
            prev_Ttr = Ttr;

            % 检查卫星是否被排除
            if ~exclude(i)
                fprintf(fid, '%d\t%d\t%f\t%f\t%f\t%f\n', epoch_time_counter, prn, Ttr, X(1, i), X(2, i), X(3, i));
            end
        end
    end

    fclose(fid);
    fprintf('卫星坐标文件已写入: %s\n', outputFileName);
end