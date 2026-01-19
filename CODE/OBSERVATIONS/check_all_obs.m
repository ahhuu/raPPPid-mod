function bool_all = check_all_obs(Epoch, n, GPS_on, GLO_on, GAL_on, BDS_on, QZS_on)
% This function checks if each satellite has the full set of observations
% it should have.
% 
% INPUT:
%   n           input frequencies for each GNSS (settings.INPUT.n_gnss_freqs)
%   Epoch       struct, epoch-specific variables
%   GPS_on, GLO_on, GAL_on, BDS_on, QZS_on    
%               boolean, true if GNSS is processed
% OUTPUT:
%	bool_all    boolean vector, true if satellite has full observation set
%
% Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Wareyka-Glaner
% *************************************************************************


% get some variables
bool_all = true(numel(Epoch.sats), 1);
C1 = Epoch.C1; C2 = Epoch.C2; C3 = Epoch.C3;
L1 = Epoch.L1; L2 = Epoch.L2; L3 = Epoch.L3;


% check if all observ
if GPS_on
    bool_all = check_obs(bool_all, C1, C2, C3, L1, L2, L3, Epoch.gps, n(1));
end
if GLO_on
    bool_all = check_obs(bool_all, C1, C2, C3, L1, L2, L3, Epoch.glo, n(2));
end
if GAL_on
    bool_all = check_obs(bool_all, C1, C2, C3, L1, L2, L3, Epoch.gal, n(3));
end
if BDS_on
    bool_all = check_obs(bool_all, C1, C2, C3, L1, L2, L3, Epoch.bds, n(4));
end
if QZS_on
    bool_all = check_obs(bool_all, C1, C2, C3, L1, L2, L3, Epoch.qzss, n(5));
end





function bool_all = check_obs(bool_all, C1, C2, C3, L1, L2, L3, gnss, n)
% check if observations on 1st frequency are exisiting
missing = isnan(C1) | isnan(L1) | C1 == 0 | L1 == 0;
% check 2nd frequency
if n >= 2
    missing = missing | isnan(C2) | isnan(L2) | C2 == 0 | L2 == 0;
end
% check third frequency
if n >= 3
    missing = missing | isnan(C3) | isnan(L3) | C3 == 0 | L3 == 0;
end
% only consider the currently checked GNSS
missing(~gnss) = 0;
bool_all(missing) = false;