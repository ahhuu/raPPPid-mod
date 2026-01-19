function [X, V, exclude, status] = ...
    satelliteOrbit(prn, Ttr, input, isGPS, isGLO, isGAL, isBDS, isQZSS, k, settings, exclude, status, corr_orb)
% Calculate (precise) satellite position.
% 
% INPUT:
% 	prn         satellite vehicle number
% 	Ttr         transmission time, sow (GPS time)
% 	input       Containing several input data (Ephemerides, etc...)
%   isGPS       boolean, GPS-satellite
%   isGLO       boolean, Glonass-satellite
%   isGAL       boolean, Galileo-satellite
%   isBDS       boolean, BeiDou-satellite
%   isQZSS      boolean, QZSS-satellite
% 	k           column of ephemerides according to time and sv
%   settings	struct with settings from GUI
%   exclude     true, if satellite has to be excluded
%   status      satellite status
%   corr_orb    current corrections to broadcast message
% 
% OUTPUT:
%   X           satellite position [m]
%   V           satellite velocity [m/s]
%   exclude     true, if satellite has to be excluded
% 
% Revision:
%   2025/02/12, MFWG: added missing conversion [mm/s] to [m/s] (corr2brdc)
%   2025/02/12, MFWG: call of function SatPos_brdc changed
% 
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

    % persistent epoch;               % epoch计数器
    % persistent first_write;         % 首次写入标志
    % persistent prev_file_info;      % 前一个文件信息
    % persistent first_prn;           % 第一个写入的卫星PRN
    % persistent written_sat_ttr;     % 记录各卫星已写入的Ttr值
    % 
    % % 获取当前处理文件名
    % current_file_info = settings.PROC.name;
    % 
    % % 检查是否开始处理新文件
    % if isempty(prev_file_info) || ~strcmp(current_file_info, prev_file_info)
    %     epoch = 0;                  % epoch初始值为0
    %     first_write = true;         % 标记首次写入
    %     first_prn = [];             % 重置首个PRN记录
    %     written_sat_ttr = containers.Map('KeyType', 'double', 'ValueType', 'any'); % 创建空容器
    %     prev_file_info = current_file_info; % 更新文件信息
    % end
    % 
    % % 初始化未定义的持久变量
    % if isempty(epoch)
    %     epoch = 1;
    % end
    % if isempty(first_write)
    %     first_write = true;
    % end
    % if isempty(first_prn)
    %     first_prn = [];
    % end
    % if isempty(written_sat_ttr)
    %     written_sat_ttr = containers.Map('KeyType', 'double', 'ValueType', 'any');
    % end

    %% 卫星轨道计算准备
    sv = mod(prn, 100);
    bool_print = ~settings.INPUT.bool_parfor;
    if isGPS
        if settings.ORBCLK.bool_sp3
            preciseEph = input.ORBCLK.preciseEph_GPS;
        end
        if settings.ORBCLK.bool_brdc
            Eph_brdc = input.ORBCLK.Eph_GPS;
            GM = Const.GM;
            we_dot = Const.WE;
        end
    elseif isGLO
        if settings.ORBCLK.bool_sp3
            preciseEph = input.ORBCLK.preciseEph_GLO;
        end
        if settings.ORBCLK.bool_brdc
            Eph_brdc = input.ORBCLK.Eph_GLO;
        end
    elseif isGAL
        if settings.ORBCLK.bool_sp3
            preciseEph = input.ORBCLK.preciseEph_GAL;
        end
        if settings.ORBCLK.bool_brdc
            Eph_brdc = input.ORBCLK.Eph_GAL;
            GM = Const.GM_GAL;
            we_dot = Const.WE_GAL;
        end
    elseif isBDS
        if settings.ORBCLK.bool_sp3
            preciseEph = input.ORBCLK.preciseEph_BDS;
        end
        if settings.ORBCLK.bool_brdc
            Eph_brdc = input.ORBCLK.Eph_BDS;
            GM = Const.GM_BDS;
            we_dot = Const.WE_BDS;        
        end 
    elseif isQZSS
        if settings.ORBCLK.bool_sp3
            preciseEph = input.ORBCLK.preciseEph_QZSS;
        end
    end

    %% 卫星位置计算
    if settings.ORBCLK.bool_sp3        % 使用精密星历
        [X, V, exclude, status] ...
            = prec_satpos(preciseEph, prn, sv, Ttr, exclude, status, bool_print);

    else        % 使用广播星历计算卫星位置
        if isGPS || isGAL
            [X,V] = SatPos_brdc(Ttr,  Eph_brdc(:,k), GM, we_dot);
        elseif isBDS
            Ttr_ = Ttr - Const.BDST_GPST;        % GPST转BDT
            [X,V] = SatPos_brdc(Ttr_, Eph_brdc(:,k), GM, we_dot);
        elseif isGLO
            [X,V] = SatPos_brdc_GLO(Ttr, Eph_brdc(:,k));
            [X] = PZ90toWGS84(X);   % 坐标系转换
            [V] = PZ90toWGS84(V);
        end
        
        % 应用轨道修正
        if settings.ORBCLK.corr2brdc_orb        
            dt = Ttr - corr_orb(1); 	% 信号发射时间与轨道修正时间差
            radial   = corr_orb(2);   along  = corr_orb(3);   outof  = corr_orb(4);     % 位置修正
            v_radial = corr_orb(5); v_along  = corr_orb(6); v_outof  = corr_orb(7);     % 速度修正
            if any(corr_orb ~= 0)
                % 获取当前有效修正值
                dr = [radial; along; outof];            % 位置修正 [m]
                dv = [v_radial; v_along; v_outof];  	% 速度修正 [mm/s]
                dv = dv / 1000;                 % mm/s转m/s
                dr = dr + dt*dv;
                [drho, drho_dot] = orb2ECEF(X, V, dr, dv);      % 转换到ECEF坐标系
                X = X - drho;                   % 修正后位置
                V = V - drho_dot;               % 修正后速度
            else
                % 无有效SSR轨道修正
                exclude = true;
                status(:) = 6;
            end
        end
    end

    % %% 数据写入处理
    % output_dir = settings.PROC.output_dir;
    % if ~exist(output_dir, 'dir')
    %     mkdir(output_dir);
    % end
    % file_path = fullfile(output_dir, 'satellite_positions.txt');
    % 
    % % 检查文件打开模式（新文件写模式，已有文件追加模式）
    % if isempty(prev_file_info) || ~strcmp(current_file_info, prev_file_info)
    %     fid = fopen(file_path, 'w');
    % else
    %     fid = fopen(file_path, 'a');
    % end
    % 
    % if fid == -1
    %     error('无法打开文件进行写入。');
    % end
    % 
    % % 首次写入时输出文件头
    % if first_write
    %     % 新文件写入列头（固定格式）
    %     fprintf(fid, '%-6s\t%-4s\t%-4s\t%24s  %24s  %24s\n', ...
    %             '#Epoch', 'PRN', 'Ttr', 'X', 'Y', 'Z');
    %     first_write = false;
    % 
    %     % 记录第一个卫星PRN
    %     first_prn = prn;
    % end
    % 
    % % 检查该卫星是否已有记录
    % if ~isKey(written_sat_ttr, prn)
    %     written_sat_ttr(prn) = [];
    % end
    % 
    % % 检查该Ttr值是否已写入过（使用容差比较浮点数）
    % if ~any(abs(written_sat_ttr(prn) - Ttr) < 1e-6)
    %     % 记录当前Ttr值
    %     written_sat_ttr(prn) = [written_sat_ttr(prn), Ttr];
    % 
    %     % 如果当前PRN等于第一个记录的PRN且不是首次记录，增加epoch
    %     if ~isempty(first_prn) && prn == first_prn
    %         epoch = epoch + 1;
    %     end
    % 
    %     % 写入卫星数据（固定格式）
    %     fprintf(fid, '%-11d\t%-4d\t%-12.6f\t%14.6f  %14.6f  %14.6f\n', ...
    %             epoch, prn, Ttr, X(1), X(2), X(3));
    % end
    % 
    % fclose(fid);

end            % end of satelliteOrbit.m