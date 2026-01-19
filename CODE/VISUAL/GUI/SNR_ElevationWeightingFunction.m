function [funhandle] = SNR_ElevationWeightingFunction(funstring)
% Convert combined SNR and elevation weighting string to function handle
% 
% INPUT:
%   funstring           string, function for combined SNR and elevation weighting
% OUTPUT:
%   funhandle           function handle, converted from the input string
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

% 检查是否已经是函数句柄
if isa(funstring, 'function_handle')
    funhandle = funstring;
    return
end

% 检查函数是否同时包含 SNR 和 e（大小写不敏感）
contains_snr = contains(lower(funstring), 'snr');
contains_e = contains(lower(funstring), 'e');

if ~contains_snr || ~contains_e
    error('Combined function must contain both "SNR" and "e".');
end

% 添加函数前缀（保留原始大小写）
if ~strncmp(funstring, '@(SNR, e)', 9) && ~strncmp(funstring, '@(snr, e)', 9)
    if strncmp(funstring, '@(', 2)
        % 保留用户的变量大小写
        funhandle = str2func(['@(SNR, e)' strrep(funstring, '@(', '')]);
    else
        % 默认使用大写 SNR
        funhandle = str2func(['@(SNR, e)' funstring]);
    end
else
    % 如果已经是正确格式，直接转换
    funhandle = str2func(funstring);
end

    % 添加调试输出
    fprintf('输入的函数字符串: %s\n', funstring);
    fprintf('生成的函数句柄: %s\n', func2str(funhandle));
    
    % 测试函数句柄是否能正常工作
    try
        test_result = funhandle(30, 10*pi/180);
        fprintf('测试结果: %.6f\n', test_result);
    catch ME
        fprintf('函数测试失败: %s\n', ME.message);
    end
    
    return;
end