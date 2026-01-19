function storeData = recover_storeData_float(floatpath, storeData)
% This function reads through results_float.txt and recovers variables of
% storeData, which correspond to the float solution
%
% INPUT:
%   floatpath       string, path to results_float.txt in results folder
%   storeData       struct, results from epoch-wise processing
% OUTPUT:
%	storeData       updated with results data
%
% Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Wareyka-Glaner
% *************************************************************************




%% --- read header ---
fid = fopen(floatpath,'rt');     	% open observation-file
header = true;
l = 0;
while header
    line = fgetl(fid);              % get next line
    l = l + 1;

    % reset epochs
    if contains(line, '# Reset of float solution in the following epochs:')
        resets = line(51:end);
        storeData.float_reset_epochs = str2num(resets);     %#ok<ST2NM>, only str2num works
    end

    % end of header
    if strcmp(line, '#************************************************** ')
        header = false;
    end

    % determine position of all extracted parameters
    if contains(line, ') Seconds of GPS week')
        i_t = str2double(line(4:5));
    end
    if contains(line, ') receiver position: x [m]')
        i_x = str2double(line(4:5));
    end
    if contains(line, ') receiver position: y [m]')
        i_y = str2double(line(4:5));
    end
    if contains(line, ') receiver position: z [m]')
        i_z = str2double(line(4:5));
    end
    if contains(line, ') receiver position: latitude [°]')
        i_lat = str2double(line(4:5));
    end
    if contains(line, ') receiver position: longitude [°]')
        i_lon = str2double(line(4:5));
    end
    if contains(line, ') receiver position: height [m]')
        i_h = str2double(line(4:5));
    end
    if contains(line, ') receiver position: x_UTM [m]')
        i_x_utm = str2double(line(4:5));
    end
    if contains(line, ') receiver position: y_UTM [m]')
        i_y_utm = str2double(line(4:5));
    end
    if contains(line, ') estimated zwd [m]')
        i_zwd_e = str2double(line(4:5));
    end
    if contains(line, ') zwd (a priori + estimate) [m]')
        i_zwd = str2double(line(4:5));
    end
    if contains(line, ') zhd modelled [m]')
        i_zhd = str2double(line(4:5));
    end

    % determine number of columns / data entries in each line
    if contains(line, '# (')
        iii = str2double(line(4:5));
    end

end
fclose(fid);



%% --- read out all data ---
fid = fopen(floatpath);
D = textscan(fid,'%f','HeaderLines', l+1);  D = D{1};
fclose(fid);



%% --- extract data ---
% create indizes
n = numel(D);               % number of entries in D
eps = n/iii;                % number of epochs
% ...
idx_t = i_t:iii:n;          % GPS time [s]
idx_x = i_x:iii:n;          % float xyz coordinates [m]
idx_y = i_y:iii:n;
idx_z = i_z:iii:n;
% ...
idx_geo_lat = i_lat:iii:n;  % latitude [°]
idx_geo_lon = i_lon:iii:n;  % longitude [°]
idx_geo_h = i_h:iii:n;      % ellipsoidal height of float position
idx_utm_x = i_x_utm:iii:n;  % float position in UTM
idx_utm_y = i_y_utm:iii:n;
% ...
idx_dzwd = i_zwd_e:iii:n;   % estimated residual zenith wet delay [m]
idx_zwd = i_zwd:iii:n;      % zenith wet delay (a priori + estimation) [m]
idx_zhd = i_zhd:iii:n;      % zenith hydrostatic delay (modeled) [m]

% ||| continue at some point



%% --- save data ---
% save GPS time
storeData.gpstime = D(idx_t);

% save float coordinates
storeData.param = zeros(eps, storeData.NO_PARAM);
storeData.param(:,1) = D(idx_x);
storeData.param(:,2) = D(idx_y);
storeData.param(:,3) = D(idx_z);
storeData.param(:,7) = D(idx_dzwd);
% save UTM coordinates
storeData.posFloat_utm = [D(idx_utm_x), D(idx_utm_y), D(idx_geo_h)];
% save float geographic coordinates
storeData.posFloat_geo = [D(idx_geo_lat), D(idx_geo_lon), D(idx_geo_h)];

% save modeled zhd
storeData.zhd = D(idx_zhd);
% rebuild and save modeled zwd
storeData.zwd = D(idx_zwd) - D(idx_dzwd);

% recalculate time to last reset
time_resets = storeData.gpstime(storeData.float_reset_epochs);
dt_ = storeData.gpstime;
r = numel(storeData.float_reset_epochs);            % number of resets
for i = r: -1 : 1
    dt_(dt_ >= time_resets(i)) = dt_(dt_ >= time_resets(i)) - time_resets(i);
end
storeData.dt_last_reset = dt_;

% create storeData.float (epochs with valid float solution)
storeData.float = all(~isnan(storeData.param(:,1:3)), 2) & all(storeData.param(:,1:3) ~= 0, 2);


% create storeData.obs_interval
storeData.obs_interval = mode(diff(storeData.gpstime));



