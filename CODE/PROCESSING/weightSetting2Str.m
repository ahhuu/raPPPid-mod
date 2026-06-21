function str = weightSetting2Str(fun_setting)
% Convert complex weighting settings to string for logging.
% This helper is shared by PPP_main and settings2txt.

if isstruct(fun_setting)
    sys_fields = builtin('fieldnames', fun_setting);
    parts = {};
    for i = 1:numel(sys_fields)
        sys = sys_fields{i};
        funs = fun_setting.(sys);
        fun_strs = {};
        for j = 1:numel(funs)
            if ischar(funs{j})
                fun_strs{end+1} = funs{j};
            else
                fun_strs{end+1} = strrep(strrep(func2str(funs{j}), '@(SNR)', ''), '@(e)', '');
            end
        end
        parts{end+1} = [sys ': ' strjoin(fun_strs, '; ')];
    end
    str = strjoin(parts, ' | ');
elseif iscell(fun_setting)
    fun_strs = {};
    for i = 1:numel(fun_setting)
        if ischar(fun_setting{i})
            fun_strs{end+1} = fun_setting{i};
        else
            fun_strs{end+1} = strrep(strrep(func2str(fun_setting{i}), '@(SNR)', ''), '@(e)', '');
        end
    end
    str = strjoin(fun_strs, '; ');
elseif isa(fun_setting, 'function_handle')
    str = strrep(strrep(func2str(fun_setting), '@(SNR)', ''), '@(e)', '');
else
    str = char(fun_setting);
end
end
