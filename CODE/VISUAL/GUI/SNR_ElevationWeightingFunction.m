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

% check if somehow already processed (struct, handle, or cell)
if isstruct(funstring) || isa(funstring,'function_handle') || iscell(funstring)
    funhandle = funstring;
    return
end

% Split by semicolon to support frequency-specific and system-specific weighting
parts = strsplit(funstring, ';');
num_parts = numel(parts);

% Initialize result structure
S = struct();
last_sys = 'default';
has_system_prefix = false;

for i = 1:num_parts
    current_str = strtrim(parts{i});
    
    % Check for system prefix (e.g., "GPS:", "G:", "GAL:")
    if contains(current_str, ':')
        tokens = strsplit(current_str, ':');
        prefix = upper(strtrim(tokens{1}));
        current_str = strtrim(strjoin(tokens(2:end), ':')); % Remove prefix from formula
        
        % Map prefix to standard system names
        switch prefix
            case {'GPS', 'G'}
                last_sys = 'GPS';
            case {'GLO', 'R'}
                last_sys = 'GLO';
            case {'GAL', 'E'}
                last_sys = 'GAL';
            case {'BDS', 'C'}
                last_sys = 'BDS';
            case {'QZSS', 'J'}
                last_sys = 'QZSS';
            otherwise
                last_sys = prefix;
        end
        has_system_prefix = true;
    end
    
    % Handle empty strings after prefix removal
    if isempty(current_str); continue; end
    
    % 检查函数是否同时包含 SNR 和 e（大小写不敏感）
    contains_snr = contains(lower(current_str), 'snr');
    contains_e = contains(lower(current_str), 'e');
    
    if ~contains_snr || ~contains_e
        error('Combined function must contain both "SNR" and "e".');
    end
    
    % Add an anonymous-function prefix only for a bare formula. Existing
    % handles are accepted regardless of argument spacing/capitalization.
    if ~strncmp(current_str, '@(', 2)
        current_str = ['@(SNR,e)' current_str];
    end
    
    % 转换并进行调试测试
    h = str2func(current_str);
    try
        h(30, 10*pi/180); % 试运行
    catch ME
        error('Function "%s" is invalid: %s', current_str, ME.message);
    end
    
    % Store in struct
    if ~isfield(S, last_sys)
        S.(last_sys) = {h};
    else
        S.(last_sys){end+1} = h;
    end
end

% Return format based on complexity
fields = fieldnames(S);
if ~has_system_prefix && numel(fields) == 1 && strcmp(fields{1}, 'default')
    % Backward compatibility: return cell array or single handle
    if numel(S.default) == 1
        funhandle = S.default{1};
    else
        funhandle = S.default;
    end
else
    % System-specific: return the full struct
    funhandle = S;
end

return;
end
