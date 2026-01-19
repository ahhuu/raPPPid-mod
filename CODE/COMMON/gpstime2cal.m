function calendar = gpstime2cal(gpsweek, gpstime)
% Convert GPS week and time into calendard date using datetime with high 
% precision. The alternative using gps2jd_GT and jd2cal_GT is significantly 
% less precise.
% Inverse function of cal2gpstime.m
% 
% INPUT:
%	gpsweek     1x1 or nx1, GPS week
%   gpstime     nx1, GPS time, seconds of week
% OUTPUT:
%   calendar    n datetime, calendar date
%
% Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Wareyka-Glaner
% *************************************************************************


% create datetime using the start of GPS time, the GPS week, and seconds of
% week
calendar = Const.GPS_timestart + days(gpsweek * 7) + seconds(gpstime);
