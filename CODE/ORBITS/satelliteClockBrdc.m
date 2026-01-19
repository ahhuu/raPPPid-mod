function [dT_clk, noclock] = satelliteClockBrdc(Ttr, Eph, isGPS, isGLO, isGAL, isBDS, isQZSS, k, corr2brdc, corr_clk)
% Calculate satellite clock from navigation message and apply corrections
% from a real-time correction stream.
%
% INPUT:
% 	Ttr         transmission time (GPStime)
% 	Eph         matrix, read-in of navigation message
% 	k           column of ephemerides according to time and sv
%   corr2brdc   boolean, from settings.ORBCLK.corr2brdc_clk
%   corr_clk    clock correction to broadcast message
%
% OUTPUT:
%   dT_clk      satellite clock correction, [s]
%   noclock     true if satellite should not be used (missing clock information)
%
% Revision:
%   2025/02/12, MFWG: added missing conversion [mm/..] to [m/..] (corr2brdc)
%   2025/09/13, MFWG: change structure
%   2025/10/02, MFWG: separate from satelliteClock.m
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************


noclock = false;
dT_clk = [];


% coefficients for navigation clock correction
if isGPS || isGAL || isBDS
    toc = Eph(21,k);
    a2 = Eph(2,k);        a1 = Eph(20,k);        a0 = Eph(19,k);
    Ttr_ = Ttr;
    if isBDS; Ttr_ = Ttr - Const.BDST_GPST; end      % convert GPST to BDT
    dT = check_t(Ttr_ - toc);           % time difference between transmission time and time of clock
    dT_clk = a2*dT^2 + a1*dT + a0;      % 2nd degree polynomial clock correction
elseif isGLO
    toe = Eph(18,k);    % epoch of ephemerides converted into GPS sow (only leap seconds accounted)
    dT = check_t(Ttr - toe);
    % dT_clk = (-Tau_N) + Gamma_N + (-Tau_C)
    dT_clk = + Eph(2,k) + Eph(3,k)*dT + Eph(16,k);
end

% --- Clock correction with correction stream
if corr2brdc
    dt = Ttr - corr_clk(1); 	% time difference between transmission time and clock correction from stream
    c0 = corr_clk(2);           % coefficients of corrections polynomial
    c1 = corr_clk(3) / 1000; 	% convert [mm/s]   to [m/s]
    c2 = corr_clk(4) / 1000; 	% convert [mm/s^2] to [m/s^2]
    dt_clock = c0 + c1*dt + c2*dt^2;    % calculate 2nd degree polynomial clock correction, [m]
    brdc_clk_corr = dt_clock/Const.C; 	% convert from [m] to [s]
    if abs(brdc_clk_corr) >= 2 || brdc_clk_corr == 0 	% no valid corrections available
        brdc_clk_corr = 0;     noclock = true;       	% eliminate satellite
    end
    dT_clk = dT_clk + brdc_clk_corr;
end


