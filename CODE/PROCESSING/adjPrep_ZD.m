function [Epoch, Adjust] = adjPrep_ZD(settings, Adjust, Epoch, prns_old, obs, input)
% This function is called in ZD_processing before the estimation of the 
% float solution with calc_float_solution.m and creates the necessary 
% variables and prediction for the parameter estimation for the
% corresponding PPP model. Furthermore, this function checks for changes in
% the sallite geometry (new or vanished satellites) and manipulates the
% parameter vector and covariance matrix accordingly.
%
% INPUT:
%   settings        struct, settings from GUI
%   Adjust          struct, all adjustment relevant data
%   Epoch           struct, epoch-specific data for current epoch
%   prns_old        satellites of previous epoch
%   obs             struct, observation-specific data
%   input           struct, input data
% OUTPUT:
%   Epoch           updated
%   Adjust          updated
%
%
% Revision:
%   2025/05/23, MFWG: adding dynamic prediction, revising everything
%   2023/11/03, MFWG: adding QZSS, improving function in several regards
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************


%% Preparation

% handle first epoch or epochs with invalid float solution (e.g., after reset)
if ~Adjust.float || strcmp(settings.ADJ.filter.type, 'No Filter')
    [Epoch, Adjust] = adjPrep_ZD_init(settings, Adjust, Epoch, obs, input);
    return      % remaining code of this function is called in all other epochs
end

% somehow this is necessary
if settings.KINE.satellite.bool && Epoch.q == settings.PROC.q_range(2) && ~Epoch.bool_2nd && ~contains(settings.PROC.method,'+ Doppler')
    Adjust.param(4:6) = (Adjust.param(1:3) - Adjust.approx_position) / obs.interval;
end

%% Get variables
% extract needed settings from structs
num_freq    = settings.INPUT.proc_freqs;
FILTER   	= settings.ADJ.filter;  	% filter settings from GUI
ZWD_ON  	= Adjust.est_ZWD;           % boolean, ZWD estimated in current epoch?

% check for processing settings
bool_phase = contains(settings.PROC.method,'+ Phase');   % true, if code+phase processing
bool_filter = ~strcmp(FILTER.type, 'No Filter');    % true if filter is enabled

% Get and create some variables
NO_PARAM = Adjust.NO_PARAM;             % number of estimated parameters
prns = Epoch.sats;                      % satellites of current epoch
no_sats_old = length(prns_old);      	% number of satellites in last epoch
no_sats = Epoch.no_sats;                % number of satellites of current epoch
s_f = no_sats*num_freq;               	% #satellites x #frequencies
N_eye = eye(s_f);                       % square unit matrix, size = number of ambiguities
N_idx = (NO_PARAM+1):(NO_PARAM+s_f);  	% indices of the ambiguities




%% Changes in satellite constellation
if bool_phase
    % get parameter vector and covariance matrix
    param = Adjust.param;  
    param_sigma = Adjust.param_sigma; 
    
    % check if satellite geometry has changed
    if ~isequal(prns, prns_old)
        % delete ambiguities of vanished satellites
        del_idx = [];
        for i = 1:no_sats_old                           % loop over satellites of last epoch
            if isempty(find(prns_old(i) == prns,1))     % find indices of vanished satellites
                del_idx(end+1) = i;
            end
        end
        if ~isempty(del_idx)	% remove ambiguities of vanished satellites
            if settings.AMBFIX.bool_AMBFIX
                % delete fixed ambiguities
                Epoch.NL_12(prns_old(del_idx)) = NaN;
                Epoch.WL_12(prns_old(del_idx)) = NaN;
                Epoch.WL_23(prns_old(del_idx)) = NaN;
                Epoch.NL_23(prns_old(del_idx)) = NaN;
            end
            no_sats_old = length(prns_old);
            prns_old = del_vec_el(prns_old, del_idx);   % exlude sats if there are also new sats
            del_idx = repmat(del_idx', 1, num_freq) + NO_PARAM + (0:num_freq-1)*no_sats_old;
            % delete ambiguities
            param = del_vec_el(param, del_idx(:));
            param_sigma = del_matr_el(param_sigma, del_idx(:));
        end
    end
    
    % test if satellite constellation is (still) different
    if ~isequal(prns, prns_old)
        % insert ambiguities (value=0) for new satellites
        ins_idx = [];
        for i = 1:no_sats                               % loop over satellites of current epoch
            if isempty(find(prns(i) == prns_old,1))  	% find indices of new satellites
                ins_idx(end+1) = i;
            end
        end
        no_sats_old = length(prns_old);
        ins_idx = repmat(ins_idx', 1, num_freq) + NO_PARAM + (0:num_freq-1)*no_sats_old;
        ins_idx = ins_idx + (0:num_freq-1)*size(ins_idx,1);  % convert ins_idx into the right format
        % add ambiguities of new satellites
        param = ins_vec_el(param, ins_idx(:), 0);
        param_sigma = ins_matr_el(param_sigma, ins_idx(:), FILTER.var_amb);
    end
        
    % save manipulated parameter vector and covariance matrix
    Adjust.param = param; 
    Adjust.param_sigma = param_sigma;
end



%% Prediction
% of parameter vector & covariance matrix with Transition Matrix and Noise Matrix
if bool_filter 
    dt = abs(Epoch.gps_time - Epoch.old.gps_time);      % absolute time difference between last and current epoch
    
    % ----- Noise Matrix -----
    Noise = Adjust.Noise_0;
    % add noise of float ambiguities
    if bool_phase
        Noise(N_idx,N_idx) = N_eye * FILTER.Q_amb;
    end
    % add ZWD noise (if ZWD estimation is not started in first epoch)
    if ZWD_ON
        Noise(7,7) = FILTER.Q_zwd;
    end
    Noise = Noise * dt/3600;     % scale process noise from 1 hour to observation interval
       
    
    % ----- Transition Matrix -----
    Transition = Adjust.Transition_0;
    % add dynamic model / prediction of coordinates
    if FILTER.dynmodel_coord == 2
        % linear model using velocity for predicting the next position
        Transition(1,4) = dt;
        Transition(2,5) = dt;
        Transition(3,6) = dt;
    end
    % add dynamic model of float ambiguities
    if bool_phase
        Transition(N_idx,N_idx) = N_eye*FILTER.dynmodel_amb;
    end

    
    % ----- covariance matrix -----
    if Adjust.est_ZWD && Adjust.param_sigma(7,7) == 1
        % check if estimation of ZWD starts in current epoch and replace 1
        % in the covariance matrix with inital variance of ZWD from GUI
        Adjust.param_sigma(7,7) = FILTER.var_zwd;
    end
    
    
    % ----- predict parameter vector -----
    Adjust.param_pred = Transition * Adjust.param;
    if isfield(Adjust, 'V_TDCP') && ~isempty(Adjust.V_TDCP)
        % Apply TDCP velocity as control input to position prediction: X_j = X_{j-1} + V * dt
        Adjust.param_pred(1:3) = Adjust.param(1:3) + dt * Adjust.V_TDCP;
    end
    if settings.KINE.satellite.bool
        % use dynamic prediction for satellite PPP
        [Adjust.param_pred(1:6), Transition] = DynamicPredictionPosVel(...
            Adjust.param, Epoch, obs, settings, Transition, Adjust.float);
    end
    
    
    % ----- predict covariance matrix of parameters -----
    % cf. [00]: p.31, (2.39) or [01]: p.247, (7.122)
    Adjust.param_sigma_pred = Transition * Adjust.param_sigma * Transition' + Noise;
    if isfield(Adjust, 'V_TDCP') && ~isempty(Adjust.V_TDCP) && norm(Adjust.V_TDCP) > 0
        % Add anisotropic TDCP velocity uncertainty to position process noise
        % East is stable (~0.01m/s), North is noisy (~0.05m/s), Up is locked (0.0m/s)
        [lat_, lon_, ~] = xyz2ell(Adjust.param(1:3)');
        sin_lon = sin(lon_); cos_lon = cos(lon_);
        sin_lat = sin(lat_); cos_lat = cos(lat_);
        R_enu2ecef = [ -sin_lon, -sin_lat*cos_lon, cos_lat*cos_lon;
                        cos_lon, -sin_lat*sin_lon, cos_lat*sin_lon;
                        0,        cos_lat,          sin_lat ];
        
        % Use dynamic anisotropic noise from settings if available
        q_east = 0.01;
        q_north = 0.05;
        q_up = 0.00;
        if isfield(settings, 'ADJ') && isfield(settings.ADJ, 'filter') && isfield(settings.ADJ.filter, 'Q_velocity')
            Q_vel = sqrt(settings.ADJ.filter.Q_velocity);
            if length(Q_vel) == 3
                q_east = Q_vel(1);
                q_north = Q_vel(2);
                q_up = Q_vel(3);
            elseif length(Q_vel) == 1
                q_north = Q_vel; % if scalar, map to north
            end
        end
        % Or override if specifically defined in settings.OTHER.tdcp_q_north
        if isfield(settings, 'OTHER') && isfield(settings.OTHER, 'tdcp_q_north')
            q_north = settings.OTHER.tdcp_q_north;
        end
        Q_enu_tdcp = diag([(dt * q_east)^2, (dt * q_north)^2, (dt * q_up)^2]);
        Q_xyz_tdcp = R_enu2ecef * Q_enu_tdcp * R_enu2ecef';
        Adjust.param_sigma_pred(1:3,1:3) = Adjust.param_sigma_pred(1:3,1:3) + Q_xyz_tdcp;
    end
    Adjust.P_pred = inv(Adjust.param_sigma_pred);       % cholinv was used before
    
    
    % ----- save Noise and Transition Matrix -----
    Adjust.Noise = Noise;
    Adjust.Transition = Transition; 
end

