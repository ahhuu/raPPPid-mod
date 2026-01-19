function check_local_files()
% 快速检查本地文件是否存在
% 运行此函数来诊断文件路径问题

fprintf('=== 检查本地文件 ===\n');

% 根据您的错误信息设置参数
gpsweek = '2378';
dow = '3';
yyyy = '2025';
doy = '218';

% 构建路径
target = [Path.DATA, 'STREAM/', yyyy, '/', doy, '/'];
fprintf('目标路径: %s\n', target);

% 检查目录
if exist(target, 'dir')
    fprintf('✓ 目录存在\n');
else
    fprintf('✗ 目录不存在\n');
    return;
end

% 检查文件
files_to_check = {
    ['cnt' gpsweek dow '.sp3.gz'],
    ['cnt' gpsweek dow '.clk.gz'],
    ['cnt' gpsweek dow '.bia.gz'],
    ['cnt' gpsweek dow '.obx.gz']
};

fprintf('\n检查文件:\n');
all_found = true;
for i = 1:length(files_to_check)
    file_path = [target files_to_check{i}];
    if exist(file_path, 'file')
        fprintf('✓ %s\n', files_to_check{i});
    else
        fprintf('✗ %s\n', files_to_check{i});
        fprintf('  完整路径: %s\n', file_path);
        all_found = false;
    end
end

if all_found
    fprintf('\n✓ 所有文件都存在！\n');
else
    fprintf('\n✗ 部分文件缺失\n');
    fprintf('请确保文件放在正确的位置\n');
end

end


