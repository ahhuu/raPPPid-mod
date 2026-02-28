function is3 = isBDS3sat(prn)
% isBDS3sat checks if a BDS satellite (or vector) belongs to BDS-3.
% BDS-3 satellites: C19-C62+ (PRN 19-62, or raPPPid internal 319-362+)
%
% INPUT:
%   prn     numeric (scalar or vector), satellite PRN in any notation
%           Accepts both raw PRN (1-60) and raPPPid internal (301-360)
% OUTPUT:
%   is3     logical, true if satellite is BDS-3
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

sv = mod(prn, 100);       % strip 300-offset if present
is3 = sv >= 19 & sv <= 62;

end
