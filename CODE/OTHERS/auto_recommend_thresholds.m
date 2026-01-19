function auto_recommend_thresholds(obs_file)
% 快捷方式：自动推荐阈值
% 
% 使用方式：
%   方法1: auto_recommend_thresholds('path/to/file.obs') - 直接指定文件路径（推荐）
%   方法2: auto_recommend_thresholds() - 尝试从 GUI 获取文件路径
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Glaner
% *************************************************************************

fprintf('\n==========================================================\n');
fprintf('  Auto-Recommend Thresholds\n');
fprintf('==========================================================\n\n');

% 如果未提供文件路径，尝试从 GUI 获取
if nargin == 0 || isempty(obs_file)
    fprintf('No file path provided. Trying to get from GUI...\n');
    
    try
        % 使用当前 figure（用户需要在 GUI 窗口中点击一下）
        fig = gcf;
        handles = guidata(fig);
        
        % 尝试从 handles 读取文件路径
        if isfield(handles, 'edit_obs') && isprop(handles.edit_obs, 'String')
            obs_file = handles.edit_obs.String;
            obs_path = getFolderPath([Path.DATA '/OBS/'], handles.paths.obs_1, handles.paths.rinex_date);
            obs_file = [obs_path, obs_file];
            fprintf('✓ Got observation file from GUI: %s\n', obs_file);
        else
            error('Could not find observation file in GUI');
        end
    catch
        fprintf('❌ Could not get observation file from GUI.\n');
        fprintf('\nPlease specify the file path:\n');
        fprintf('  auto_recommend_thresholds(''path/to/file.obs'')\n\n');
        fprintf('Example for your smartphone data:\n');
        fprintf('  auto_recommend_thresholds(''D:\\\\code\\\\matlab\\\\raPPPid\\\\raPPPid\\\\DATA\\\\OBS\\\\2025\\\\218\\\\cleaned2-K7new_gnss_log_2025_08_06_09_24_40-cc inconsistency.25o'')\n\n');
        return;
    end
end

% 检查文件是否存在
if ~exist(obs_file, 'file')
    fprintf('❌ File not found: %s\n', obs_file);
    return;
end

fprintf('Observation file: %s\n', obs_file);

% 创建基本设置
settings = struct();
settings.INPUT.file_obs = obs_file;
settings.INPUT.use_GPS = true;
settings.INPUT.use_GLO = false;
settings.INPUT.use_GAL = false;
settings.INPUT.use_BDS = false;
settings.INPUT.use_QZSS = false;
settings.INPUT.gps_freq = {'1F', '2W'};
settings.INPUT.rawDataAndroid = false;

% 调用自动推荐
try
    addpath([pwd, '/CODE/OTHERS']);
    [recommended, quality_report] = autoRecommendThresholds(settings);
    rmpath([pwd, '/CODE/OTHERS']);
    
    % 显示结果
    fprintf('\n=========================================================\n');
    fprintf('  RECOMMENDATIONS\n');
    fprintf('=========================================================\n');
    fprintf('Device Type: %s\n', quality_report.device_type);
    fprintf('Observation Interval: %.1f [s]\n', quality_report.obs_interval);
    fprintf('\n--- Apply in GUI ---\n');
    fprintf('1. Go to: Models → Other Corrections\n');
    fprintf('   • Check "Doppler Shift"\n');
    fprintf('   • Threshold: %.2f [cycles]\n', recommended.OTHER.CS.D_threshold);
    fprintf('\n2. Go to: Estimation → Weighting\n');
    fprintf('   • Code: %.3f [m]\n', sqrt(recommended.ADJ.var_code));
    fprintf('   • Phase: %.3f [m]\n', sqrt(recommended.ADJ.var_phase));
    fprintf('=========================================================\n\n');
    
catch ME
    fprintf('❌ Error: %s\n', ME.message);
end

end
