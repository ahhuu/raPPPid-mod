function settings = recover_settings(path)
% This function recovers/rebuilds the variable settings from the data in
% the text file settings_summary.txt
%
% INPUT:
%	path            string, path to results folder of processing or
%                   directly to the settings_summary.txt-file
% OUTPUT:
%	settings        struct, contains recovered fields
%
% Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************


% ||| continue when needed


% initialize
settings = struct;

% open, read and close file
if ~isfile(path);   path = [path '/settings_summary.txt'];   end
fid = fopen(path);
TXT = textscan(fid,'%s', 'delimiter','\n', 'whitespace','');
TXT = TXT{1};
fclose(fid);

% detect processing name
bool_proc_name = contains(TXT, '  Processing name:');
if any(bool_proc_name)
    line_proc_name = TXT{bool_proc_name};
    idx = strfind(line_proc_name, 'name:');
    settings.PROC.name = line_proc_name(idx+6:end); 
end
