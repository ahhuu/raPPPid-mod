function C_i2e = dcm_eci_2_ecef(UTC_Time)
% Convert Earth-centered inertial (ECI) to Earth-centered Earth-fixed
% (ECEF) coordinates.
%
% INPUT:
%   UTC_Time
% OUTPUT:
%	C_i2e
%
% Revision:
%   ...
%
% Created by Hoor Bano
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Wareyka-Glaner
% *************************************************************************

jd = juliandate(UTC_Time);
T = (jd - 2451545.0) / 36525;      % centuries since J2000

gmst_sec = 67310.54841 ...
    + (876600*3600 + 8640184.812866)*T ...
    + 0.093104*(T^2) ...
    - (6.2e-6)*(T^3);

gmst_sec = mod(gmst_sec, 86400);
theta    = gmst_sec * (pi/43200);

C_i2e = [cos(theta), sin(theta),  0;
    -sin(theta), cos(theta), 0;
    0, 0, 1];

% C_i2e = dcmeci2ecef('IAU-2000/2006', UTC_Time);
end