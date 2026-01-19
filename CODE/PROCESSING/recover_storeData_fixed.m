function storeData = recover_storeData_fixed(fixedpath, storeData)
% This function reads through results_fixed.txt and recovers variables of
% storeData, which correspond to the fixed solution
%
% INPUT:
%   fixedpath       string, path to results_fixed.txt in results folder
%   storeData       struct, results from epoch-wise processing
% OUTPUT:
%	storeData       updated with results data
%
% Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Wareyka-Glaner
% *************************************************************************


storeData.fixed_reset_epochs = 1;



%% --- read header ---
fid = fopen(fixedpath,'rt');      	% open observation-file
header = true;
l = 0;
while header
    line = fgetl(fid);              % get next line
    l = l + 1;

    % reset epochs
    if contains(line, '# Reset of fixed solution in the following epochs:')
        resets = line(51:end);
        storeData.fixed_reset_epochs = str2num(resets);     %#ok<ST2NM>, only str2num works
    end

    % determine position of all extracted parameters
    if contains(line, ') receiver position: x [m]')
        i_x = str2double(line(4:5));
    end
    if contains(line, ') receiver position: y [m]')
        i_y = str2double(line(4:5));
    end
    if contains(line, ') receiver position: z [m]')
        i_z = str2double(line(4:5));
    end
    if contains(line, ') receiver position: latitude [°]') || contains(line, ') receiver position: phi [°]')
        i_lat = str2double(line(4:5));
    end
    if contains(line, ') receiver position: longitude [°]') || contains(line, ') receiver position: lambda [°]')
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

    % end of header
    if strcmp(line, '#************************************************** ')
        header = false;
    end

    % determine number of columns / data entries in each line
    if contains(line, '# (')
        iii = str2double(line(4:5));
    end

end
fclose(fid);



%% --- read out all data ---
fid = fopen(fixedpath);
D = textscan(fid,'%f','HeaderLines', l+1);  D = D{1};
fclose(fid);



%% --- extract data ---
% create indizes
n = numel(D);
% ...
idx_x = i_x:iii:n;               % fixed xyz coordinates [m]
idx_y = i_y:iii:n;
idx_z = i_z:iii:n;
% ...
idx_geo_lat = i_lat:iii:n;       % latitude [°]
idx_geo_lon = i_lon:iii:n;       % longitude [°]
idx_geo_h = i_h:iii:n;           % ellipsoidal height [m]
idx_utm_x = i_x_utm:iii:n;       % fixed position in UTM [m]
idx_utm_y = i_y_utm:iii:n;
% ||| continue at some point



%% --- save data ---
% save fixed coordinates
storeData.param_fix = [D(idx_x), D(idx_y), D(idx_z)];
storeData.posFixed_utm = [D(idx_utm_x), D(idx_utm_y), D(idx_geo_h)];
storeData.posFixed_geo = [D(idx_geo_lat), D(idx_geo_lon), D(idx_geo_h)];

% create storeData.fixed (epochs with valid fixed solution)
storeData.fixed = all(~isnan(storeData.param_fix), 2) & all(storeData.param_fix ~= 0, 2);

