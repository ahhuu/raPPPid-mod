function [funhandle] = SNRWeightingFunction(funstring)
% Convert C/N0 weighting string from GUI to function handle
% 
% INPUT:
%   funstring           string, function for elevation weighting from GUI      
% OUTPUT:
%	funhandle           function handle, converted from the input string
%
% Revision:
%   ...
%
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
    
    % check if hardcoded option of SNR weighting function is in use
    if contains(current_str, 'option')
        h = current_str;
    else
        % check string for valid beginning for conversion
        if ~strncmp(current_str, '@(', 2)
            current_str = ['@(SNR)' current_str];
        end
        % convert string to function handle
        h = str2func(current_str);
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
