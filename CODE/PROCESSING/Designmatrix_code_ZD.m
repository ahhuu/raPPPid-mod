function Adjust = Designmatrix_code_ZD(Adjust, Epoch, model, settings)
% Creates Design-Matrix and calculates observed minus computed range for 
% code solution and Zero-Difference-Model
% 
% INPUT:  
%	Adjust   	...
%	Epoch     	epoch-specific data
% 	model    	struct, model corrections for all visible sats
%   settings 	struct, settings of processing from GUI
% OUTPUT: 
%   Adjust      updated with A, omc
%
%   Revision:
%       ...
% 
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************


% --- Preparations
num_freq = settings.INPUT.proc_freqs;
param = Adjust.param;       % parameter estimations from last epoch
obs_code = Epoch.code;      % code observations [m] of current epoch
no_sats = numel(Epoch.sats);% number of satellites in current epoch
s_f = no_sats * num_freq;

% logical vector for all frequencies, true if satellite belongs to this GNSS
isGPS  = repmat(Epoch.gps,  num_freq, 1); 	
isGLO  = repmat(Epoch.glo,  num_freq, 1);  
isGAL  = repmat(Epoch.gal,  num_freq, 1);  	
isBDS  = repmat(Epoch.bds,  num_freq, 1); 
isQZSS = repmat(Epoch.qzss, num_freq, 1);  

% BDS-2/BDS-3 ISB support
bds23_isb_on = isfield(settings.BIASES, 'estimate_bds23_isb') && settings.BIASES.estimate_bds23_isb;
bds23_isb_mode = 'free';
if bds23_isb_on && isfield(settings.BIASES, 'bds23_isb_mode')
    bds23_isb_mode = settings.BIASES.bds23_isb_mode;
end
bds23_isb_split_on = bds23_isb_on && strcmp(bds23_isb_mode, 'split');
bds23_isb_state_on = bds23_isb_on && ismember(bds23_isb_mode, {'free','split','constrained'});
if bds23_isb_state_on
    isBDS3 = repmat(Epoch.bds3, num_freq, 1);
end
if bds23_isb_split_on
    isBDS2 = repmat(Epoch.bds2, num_freq, 1);
end

NO_PARAM = Adjust.NO_PARAM;  % dynamic: 19 or 22

exclude = Epoch.exclude(:);         % true = satellite excluded
rho = model.rho(:);                 % geometric distance
sat_pos_x = repmat(model.Rot_X(1,:)', 1, num_freq);  	% satellite ECEF position x
sat_pos_y = repmat(model.Rot_X(2,:)', 1, num_freq);  	% satellite ECEF position y
sat_pos_z = repmat(model.Rot_X(3,:)', 1, num_freq);  	% satellite ECEF position z

% --- observed minus computed
omc = (obs_code(:) - model.model_code(:)) .* ~exclude;

% --- Partial derivatives
% coordinates
dR_dx    = -( sat_pos_x(:)-param(1) ) ./ rho;         % x
dR_dy    = -( sat_pos_y(:)-param(2) ) ./ rho;         % y
dR_dz    = -( sat_pos_z(:)-param(3) ) ./ rho;         % z

% troposphere
dR_dtrop =  model.mfw(:);       % wet mapping function

% clock and DCBs
dR_time_dcb = zeros(s_f, NO_PARAM - 4);
% receiver clock error
if settings.INPUT.use_GPS
    dR_time_dcb(:, 1) = isGPS + isGLO + isGAL + isBDS + isQZSS;       % GPS receiver clock error
end
% time offsets
dR_time_dcb(:, 4) = isGLO;       % GLONASS
dR_time_dcb(:, 7) = isGAL;       % Galileo
dR_time_dcb(:,10) = isBDS;       % BeiDou common clock (all BDS sats)
dR_time_dcb(:,13) = isQZSS;      % QZSS
if bds23_isb_split_on
    dR_time_dcb(:,10) = isBDS2;      % BeiDou-2 clock (split mode)
    dR_time_dcb(:,16) = isBDS3;      % BeiDou-3 clock (split mode)
elseif bds23_isb_state_on
    dR_time_dcb(:,16) = isBDS3;      % BeiDou-3 (param 20)
end
% Differential Code Biases
if settings.BIASES.estimate_rec_dcbs
    % DCBs between 1st and 2nd frequency
    if num_freq > 1
        frq_2 = (no_sats+1):2*no_sats;
        dR_time_dcb(frq_2, 2) = -isGPS(frq_2);   	% GPS
        dR_time_dcb(frq_2, 5) = -isGLO(frq_2);   	% GLONASS
        dR_time_dcb(frq_2, 8) = -isGAL(frq_2);   	% Galileo
        dR_time_dcb(frq_2,11) = -isBDS(frq_2);   	% BeiDou (shared DCB12 for all BDS sats)
        dR_time_dcb(frq_2,14) = -isQZSS(frq_2);   	% QZSS
    end
    % DCBs between 1st and 3rd frequency
    if num_freq > 2
        frq_3 = (2*no_sats+1):3*no_sats;
        dR_time_dcb(frq_3, 3) = -isGPS(frq_3);  	% GPS
        dR_time_dcb(frq_3, 6) = -isGLO(frq_3);   	% GLONASS
        dR_time_dcb(frq_3, 9) = -isGAL(frq_3);    	% Galileo
        dR_time_dcb(frq_3,12) = -isBDS(frq_3);   	% BeiDou (shared DCB13 for all BDS sats)
        dR_time_dcb(frq_3,15) = -isQZSS(frq_3);   	% QZSS
    end
end

% --- Build A-Matrix
A = [dR_dx, dR_dy, dR_dz, dR_dtrop, dR_time_dcb] .* ~exclude;

% --- add ionosphere estimation part to A and omc
if strcmpi(settings.IONO.model,'Estimate with ... as constraint') || strcmpi(settings.IONO.model,'Estimate')
    % --- Design Matrix A
    dR_diono_code_f1  =  Epoch.f1.^2 ./ Epoch.f1.^2;
    A_iono = diag(dR_diono_code_f1);
    if num_freq > 1         % 2nd frequency is processed
        dR_diono_code_f2  =  Epoch.f1.^2 ./ Epoch.f2.^2;
        A_iono_2 = diag(dR_diono_code_f2);
        A_iono = [A_iono; A_iono_2];
        if num_freq > 2     % 3rd frequency is processed
            dR_diono_code_f3  =  Epoch.f1.^2 ./ Epoch.f3.^2;
            A_iono_3 = diag(dR_diono_code_f3);
            A_iono = [A_iono; A_iono_3];
        end
    end  
    A_iono(Epoch.exclude(:), :) = 0;   	% remove iono estimation of excluded satellites
    % Put Design-Matrix together
    A = [A, A_iono];
    if strcmpi(settings.IONO.model,'Estimate with ... as constraint') && Adjust.constraint
        % --- Ionospheric Pseudo-observations
        A_iono_observ = [zeros(no_sats, Adjust.NO_PARAM), eye(no_sats)];
        A = [A; A_iono_observ];
        % --- observed-minus-computed
        n = numel(Adjust.param);    % initialize estimated ionospheric delay
        iono_est = Adjust.param(n-no_sats+1:n);
        omc_iono = model.iono(:,1) - iono_est;
        omc = [omc(:); omc_iono(:)];
    end
end


%% --- save in Adjust
Adjust.A = A;
Adjust.omc = omc;
