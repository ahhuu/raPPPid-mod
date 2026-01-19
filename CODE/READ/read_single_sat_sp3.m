function [SP3] = read_single_sat_sp3(filename)
% Reads precise ephemerides from single‐satellite sp3 file.
%
% INPUT:
% 	filename        string with path and name of .sp3 file
% OUPUT:
% 	SP3:          	struct with following elements (row = epoch)
%       SP3.t:         	time in sec. of week
%       SP3.x:          x coordinate of satellite [m]
%       SP3.y:          y coordinate of satellite [m]
%       SP3.z:          z coordinate of satellite [m]
%       SP3.dt:         clock correction [s]
%
%   Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Wareyka-Glaner
% *************************************************************************

% Initialization
SP3 = [];

% open and read sp3-file
fid = fopen(filename);          % open file
lines = textscan(fid,'%s', 'delimiter','\n', 'whitespace','');
lines = lines{1};
fclose(fid);
no_lines = length(lines);   % number of lines of file

i = 1;
while 1                 % loop to go to the first entry
    tline = lines{i};   i = i + 1;
    if (tline(1) == '*')
        break
    end
end

idx = 0; 	% index of epoch
while i <= no_lines         % loop till end of file
    if tline(1) ~= '*'
        continue
    end
    date = sscanf(tline,'%*c %f %f %f %f %f %f')';      % start with epoch header (always in GPS time)
    time = datetime(date);
    [~, sow] = cal2gpstime(time);
    idx = idx + 1;          % increase epoch index

    tline = lines{i};   i = i + 1;
    while tline(1) ~= '*' && tline(1) ~= 'E'            % loop over data entry

        % - get data
        type = tline(1);                % Position or Velocity data
        epdata = sscanf(tline(5:end),'%f');
        X = epdata(1);
        Y = epdata(2);
        Z = epdata(3);
        dT = epdata(4)*10^-6;        % [microsec] to [s]
        if dT >= 0.1                 % sometimes dt is denoted as 99999.99
            dT = 0;
        end

        % - save data
        if type == 'P'          % Position data
            SP3 = save_position(SP3, idx, 1, sow, X, Y, Z, dT, time);
        elseif type == 'V'      % Velocity data
            SP3 = save_velocity(SP3, idx, 1, sow, X, Y, Z, dT, time);
        end

        % - get next line (if possible)
        if i > no_lines; break; end
        tline = lines{i};   i = i + 1;

    end     % loop over data entry
end     % loop till end of file


% save-function for position
function SAT = save_position(SAT, i, col, sow, X, Y, Z, dT, time)
SAT.t (i, col)	 = sow;
SAT.time(i, col) = time;
SAT.X (i, col)	 = X*1000;       % [km] to [m]
SAT.Y (i, col)	 = Y*1000;
SAT.Z (i, col)   = Z*1000;
SAT.dT(i, col)   = dT;


% save-function for velocity
function SAT = save_velocity(SAT, i, col, sow, X, Y, Z, dT, time)
SAT.t_vel (i, col)	 = sow;
SAT.time_vel(i, col) = time;
SAT.X_vel (i, col)	 = X/10;     % [dm/s] to [m/s]
SAT.Y_vel (i, col)	 = Y/10;
SAT.Z_vel (i, col)   = Z/10;
SAT.dT_vel(i, col)   = dT;

