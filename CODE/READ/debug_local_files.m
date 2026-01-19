function debug_local_files()
% 调试本地文件检查问题
% 帮助诊断为什么本地文件没有被找到

fprintf('=== 调试本地文件检查问题 ===\n');

% 设置测试参数（根据您的错误信息）
gpsweek = '2378';
dow = '3';
yyyy = '2025';
mm = '08';
doy = '218';

% 构建目标路径
target = [Path.DATA, 'STREAM/', yyyy, '/', doy, '/'];
fprintf('目标路径: %s\n', target);

% 检查路径是否存在
if exist(target, 'dir')
    fprintf('✓ 目标目录存在\n');
else
    fprintf('✗ 目标目录不存在\n');
    fprintf('尝试创建目录...\n');
    [~, ~] = mkdir(target);
    if exist(target, 'dir')
        fprintf('✓ 目录创建成功\n');
    else
        fprintf('✗ 目录创建失败\n');
        return;
    end
end

% 列出目录中的所有文件
files_in_dir = dir(target);
fprintf('\n目录中的文件:\n');
for i = 1:length(files_in_dir)
    if ~files_in_dir(i).isdir
        fprintf('  - %s\n', files_in_dir(i).name);
    end
end

% 检查期望的文件
expected_files = {
    ['cnt' gpsweek dow '.sp3.gz'],
    ['cnt' gpsweek dow '.clk.gz'],
    ['cnt' gpsweek dow '.bia.gz'],
    ['cnt' gpsweek dow '.obx.gz']
};

fprintf('\n检查期望的文件:\n');
for i = 1:length(expected_files)
    file_path = [target expected_files{i}];
    if exist(file_path, 'file')
        fprintf('✓ 找到文件: %s\n', expected_files{i});
        % 检查文件大小
        file_info = dir(file_path);
        fprintf('  文件大小: %d bytes\n', file_info.bytes);
    else
        fprintf('✗ 未找到文件: %s\n', expected_files{i});
        fprintf('  完整路径: %s\n', file_path);
    end
end

% 检查未压缩的文件
uncompressed_files = {
    ['cnt' gpsweek dow '.sp3'],
    ['cnt' gpsweek dow '.clk'],
    ['cnt' gpsweek dow '.bia'],
    ['cnt' gpsweek dow '.obx']
};

fprintf('\n检查未压缩的文件:\n');
for i = 1:length(uncompressed_files)
    file_path = [target uncompressed_files{i}];
    if exist(file_path, 'file')
        fprintf('✓ 找到未压缩文件: %s\n', uncompressed_files{i});
    else
        fprintf('✗ 未找到未压缩文件: %s\n', uncompressed_files{i});
    end
    
    % 检查 .mat 文件
    mat_file_path = [file_path '.mat'];
    if exist(mat_file_path, 'file')
        fprintf('✓ 找到 .mat 文件: %s\n', [uncompressed_files{i} '.mat']);
    end
end

% 提供建议
fprintf('\n=== 建议 ===\n');
fprintf('1. 确保文件放在正确的目录: %s\n', target);
fprintf('2. 检查文件名格式是否正确，应该包含 GPS 周和星期几\n');
fprintf('3. 如果文件在其他位置，请移动到正确目录\n');
fprintf('4. 检查文件权限，确保 MATLAB 可以读取\n');

fprintf('\n=== 调试完成 ===\n');
end


