function test_cas_archive_formats()
% 测试CAS Archive新格式支持
% 验证1分钟和5分钟格式的兼容性

fprintf('=== 测试CAS Archive格式支持 ===\n');

% 设置测试参数
yyyy = '2025';
doy = '218';

% 构建目标路径
target = [Path.DATA, 'STREAM/', yyyy, '/', doy, '/'];
fprintf('目标路径: %s\n', target);

% 检查目录
if exist(target, 'dir')
    fprintf('✓ 目标目录存在\n');
else
    fprintf('✗ 目标目录不存在，创建中...\n');
    [~, ~] = mkdir(target);
    if exist(target, 'dir')
        fprintf('✓ 目录创建成功\n');
    else
        fprintf('✗ 目录创建失败\n');
        return;
    end
end

% 定义文件格式
formats = {'01M', '05M'};
file_types = {'ORB.SP3', 'CLK.CLK'};

fprintf('\n检查CAS Archive文件:\n');

for i = 1:length(formats)
    format = formats{i};
    fprintf('\n格式: %s (间隔: %s)\n', format, getIntervalDescription(format));
    
    for j = 1:length(file_types)
        file_type = file_types{j};
        file_name = ['CAS0MGXRTS_' yyyy doy '0000_01D_' format '_' file_type '.gz'];
        file_path = [target file_name];
        
        if exist(file_path, 'file')
            fprintf('✓ 找到文件: %s\n', file_name);
            % 检查文件大小
            file_info = dir(file_path);
            fprintf('  文件大小: %d bytes\n', file_info.bytes);
        else
            fprintf('✗ 未找到文件: %s\n', file_name);
        end
        
        % 检查未压缩文件
        uncompressed_name = ['CAS0MGXRTS_' yyyy doy '0000_01D_' format '_' file_type];
        uncompressed_path = [target uncompressed_name];
        if exist(uncompressed_path, 'file')
            fprintf('✓ 找到未压缩文件: %s\n', uncompressed_name);
        end
    end
end

% 提供建议
fprintf('\n=== 建议 ===\n');
fprintf('1. 优先使用1分钟间隔格式 (01M) 以获得更高精度\n');
fprintf('2. 如果1分钟格式不可用，系统会自动回退到5分钟格式 (05M)\n');
fprintf('3. 确保文件放在正确目录: %s\n', target);
fprintf('4. 文件名格式: CAS0MGXRTS_YYYYDOY0000_01D_XXM_TYPE.gz\n');

fprintf('\n=== 测试完成 ===\n');
end

function desc = getIntervalDescription(format)
% 获取格式描述
switch format
    case '01M'
        desc = '1分钟';
    case '05M'
        desc = '5分钟';
    case '30S'
        desc = '30秒';
    otherwise
        desc = '未知';
end
end


