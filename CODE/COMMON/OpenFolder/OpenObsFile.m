function [] = OpenObsFile(settings)
% Opens the processed observation file with the default text editor.
% 
% INPUT:
%   settings    struct, processing settings
% OUTPUT:
%	[]
%
% Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Wareyka-Glaner
% *************************************************************************

% convert relative to absolute path (observations file)
info = dir(settings.INPUT.file_obs);
ObsFilePath = fullfile(info.folder, info.name);

% open with default text editor
if ispc
    system(['start ' ObsFilePath]);
elseif isunix
    system(['xdg-open ' ObsFilePath]);
else
    system(['open ' ObsFilePath]);
end
