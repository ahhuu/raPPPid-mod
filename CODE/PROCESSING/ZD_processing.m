function [Adjust, Epoch, model, obs] = ZD_processing(Adjust, Epoch, settings, input, obs)

% Processing one epoch using a zero-difference observation model for the
% float solution. 
% Only for ambiguity fixing (2-frequency IF-LC) a reference satellite is 
% chosen to calculate satellite single-differences and, therefore, eliminate  
% the receiver phase hardware delays.
% 
% INPUT:
% 	Adjust      adjustment data and matrices for current epoch [struct]
%	Epoch       epoch-specific data for current epoch [struct]
%	settings    settings from GUI [struct]
%	input       input data e.g. ephemerides and additional data  [struct]
%   obs         observation-specific data [struct]
% OUTPUT:
%	Adjust      adjustment data and matrices for current epoch [struct]
%	Epoch       epoch-specific data for current epoch [struct]
%  	model       model corrections for all visible satellites [struct]
%   obs         observation-specific data [struct]
%
% 
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************



%% ------ Float Solution -------

% Calculate TDCP velocity externally as control input if enabled
if isfield(settings.OTHER, 'use_tdcp_as_doppler') && settings.OTHER.use_tdcp_as_doppler
        if isfield(Adjust, 'param') && ~isempty(Adjust.param)
            pos_ref = Adjust.param(1:3);
        else
            pos_ref = ApproximatePosition(Epoch, input, obs, settings);
        end
        [V_TDCP, ~] = ApproximateVelocity(Epoch, input, obs, settings, pos_ref);
        
        % Adaptive Kinematics: Only apply TDCP velocity external control input after convergence
        % (based on posterior 3D coordinate standard deviation from covariance matrix).
        if isfield(Adjust, 'param_sigma') && ~isempty(Adjust.param_sigma) && size(Adjust.param_sigma, 1) >= 3
            sigma_3D = sqrt(sum(diag(Adjust.param_sigma(1:3, 1:3))));
        else
            sigma_3D = 999.0; % Default to large uncertainty if not initialized
        end
        
        % Time-domain convergence check (Epoch >= 120) since coordinate covariance (param_sigma) 
        % is often overly pessimistic due to high multipath, preventing activation under 0.1m.
        if Epoch.q < 120
            Adjust.V_TDCP = [0; 0; 0];
        else
            % Project ECEF velocity to ENU and lock vertical velocity (Up) to 0
            [lat_, lon_, ~] = xyz2ell(pos_ref');
            sin_lon = sin(lon_); cos_lon = cos(lon_);
            sin_lat = sin(lat_); cos_lat = cos(lat_);
            R_enu2ecef = [ -sin_lon, -sin_lat*cos_lon, cos_lat*cos_lon;
                            cos_lon, -sin_lat*sin_lon, cos_lat*sin_lon;
                            0,        cos_lat,          sin_lat ];
            R_ecef2enu = R_enu2ecef';
            
            V_enu = R_ecef2enu * V_TDCP;
            V_enu(3) = 0; % Lock vertical velocity to 0 since receiver moves on horizontal plane
            
            Adjust.V_TDCP = R_enu2ecef * V_enu;
        end
        
        if Epoch.q <= 10
            fprintf('TEST: Epoch %d, sigma_3D = %.3f m, V_TDCP = [%.4f, %.4f, %.4f] m/s\n', Epoch.q, sigma_3D, V_TDCP(1), V_TDCP(2), V_TDCP(3));
        end
    else
        Adjust.V_TDCP = [0; 0; 0];
    end

% preparation of parameter estimation (depending on PPP model)
switch settings.IONO.model
    case {'Estimate with ... as constraint', 'Estimate'}
        [Epoch, Adjust] = adjPrep_iono(settings, Adjust, Epoch, Epoch.old.sats, obs, input);
    case 'Estimate, decoupled clock'
        [Epoch, Adjust] = adjPrep_DCM(settings, Adjust, Epoch, Epoch.old.sats, obs, input);
    otherwise
        [Epoch, Adjust] = adjPrep_ZD(settings, Adjust, Epoch, Epoch.old.sats, obs, input);
end

% estimation of float paramaters
[Epoch, Adjust, model] = calc_float_solution(input, obs, Adjust, Epoch, settings);


%% ------ Fixed Solution ------

if settings.AMBFIX.bool_AMBFIX && ~strcmp(settings.IONO.model, 'Estimate, decoupled clock')
    
    % --- build HMW LC ---
    [Adjust] = create_HMW_LC(Epoch, settings, Adjust, model.los_APC);
    
    if Adjust.fix_now(1)
        
        % --- check which satellites are fixable
        Epoch = CheckSatellitesFixable(Epoch, settings, model, input);
        
        % --- choose reference satellite for fixing ---
        [Epoch, Adjust] = handleRefSats(Epoch, model.el, settings, Adjust);
        
        % --- start fixing depending on PPP model ---
        % decoupled clock model is handled seperately
        switch settings.IONO.model
            case '2-Frequency-IF-LCs'
                [Epoch, Adjust] = PPPAR_IF(Adjust, Epoch, settings, input, obs, model);
                
            case '3-Frequency-IF-LCs'
                [Epoch, Adjust] = PPPAR_3IF(Adjust, Epoch, settings, input, obs, model);
                
            case {'Estimate with ... as constraint', 'Estimate', 'off'}     % off: simulated data
                [Epoch, Adjust] = PPPAR_UC(Adjust, Epoch, settings, obs, model);
                
            otherwise
                fprintf(2, '\nPPP-AR is not implemented for this ionosphere model!\n')
        end
    end

elseif settings.AMBFIX.bool_AMBFIX
    % Decoupled Clock Model: integer ambiguity fixing and fixed solution

    % check which satellites are fixable
    Epoch = CheckSatellitesFixable(Epoch, settings, model, input);
    % fix ambiguities and calculate fixed solution
    [Epoch, Adjust] = PPPAR_DCM(Adjust, Epoch, settings);

end

