function [vec, ticks] = duration2ticks(duration)
% Create ticks depending on duration of plot.
% 
% INPUT:
%   duration            [h]
% OUTPUT:
%	ticks               text to vec
%   vec                 [s]
%
% Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Wareyka-Glaner
% *************************************************************************

duration_s = duration * 3600;   % [s]

% determine interval of xlabelling
if duration < 0.20
    vec = 0:120:duration_s;         % 2min interval
elseif duration < 0.5
    vec = 0:300:duration_s;         % 5min interval
elseif duration < 1
    vec = 0:(3600/4):duration_s;    % 15min interval
elseif duration < 2
    vec = 0:(3600/2):duration_s;    % 30min interval
elseif duration < 4
    vec = 0:3600:duration_s;        % 1h interval
elseif duration < 9
    vec = 0:(3600*2):duration_s;   	% 2h interval
else
    vec = 0:(3600*4):duration_s;    % 4h interval
end

% create ticks
ticks = sow2hhmm(vec);