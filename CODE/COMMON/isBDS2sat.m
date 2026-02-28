function is2 = isBDS2sat(prn)
% isBDS2sat checks if a BDS satellite (or vector) belongs to BDS-2.
% BDS-2 satellites: C01-C18 (PRN 1-18, or raPPPid internal 301-318)
%
% INPUT:
%   prn     numeric (scalar or vector), satellite PRN in any notation
%           Accepts both raw PRN (1-60) and raPPPid internal (301-360)
% OUTPUT:
%   is2     logical, true if satellite is BDS-2
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

sv = mod(prn, 100);       % strip 300-offset if present
is2 = sv >= 1 & sv <= 18;

end
