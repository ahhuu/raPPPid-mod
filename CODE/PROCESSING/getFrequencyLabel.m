function freq_label = getFrequencyLabel(prn, freq_idx, settings)
% 根据卫星PRN和频率索引，从settings中获取配置的频率标签
% (如 'C1C', 'C5Q', 'C2I' 等)
%
% INPUT:
%   prn          整数，卫星PRN号（1-399，按照raPPPid编码规则）
%   freq_idx     整数，频率索引 (1, 2, 3)
%   settings     struct，处理设置（包含 INPUT.gps_freq, gal_freq等字段）
% OUTPUT:
%   freq_label   字符串，频率观测类型标签（如 'C1C', 'C5Q', 'C2I'）
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% Modified to read from settings.INPUT, 2026
% *************************************************************************

% 确定卫星系统and对应的频率配置字段
if prn <= 99
    freq_settings = settings.INPUT.gps_freq;
elseif prn >= 101 && prn <= 199
    freq_settings = settings.INPUT.glo_freq;
elseif prn >= 201 && prn <= 299
    freq_settings = settings.INPUT.gal_freq;
elseif prn >= 301 && prn <= 399
    freq_settings = settings.INPUT.bds_freq;
elseif prn >= 401 && prn <= 410
    freq_settings = settings.INPUT.qzss_freq;
else
    freq_label = 'UNKNOWN';
    return;
end

% 检查频率索引是否有效
if freq_idx > length(freq_settings) || strcmpi(freq_settings{freq_idx}, 'OFF')
    freq_label = 'OFF';
    return;
end

% 获取频率代码（如：'L1', 'L5',  'B1', 'B1AC', 'B2a'等）并转换为观测类型标签
freq_code = freq_settings{freq_idx};
if ~isempty(freq_code)
    freq_label = freq_code;  % 直接返回频率代码
else
    freq_label = 'UNKNOWN';
end

end
