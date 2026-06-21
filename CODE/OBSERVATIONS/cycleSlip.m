function [Epoch] = cycleSlip(Epoch, settings, use_column, varargin)
% Performs cycle-slip detection. It is possible to insert artificial cycle
% slip into the observations by uncommenting and editing the function 
% cycleSlip_artificial.m (in PPP_main.m)
%
% INPUT:
%   Epoch       struct, epoch-specific data
%   settings	struct, settings from GUI
%   use_column	cell, used columns of observation matrix for all GNSS and observation types
%   varargin    optional arguments: input, last_pos, obs
% OUTPUT:
%   Epoch       update of .cs_found and added some Cycle-Slip calculations
%  
% Revision:
%   2023/06/11, MFWG: adding QZSS
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

if contains(settings.PROC.method, 'Phase')  % except code only solution
    input = [];
    last_pos = [];
    obs = [];
    if nargin >= 6
        input = varargin{1};
        last_pos = varargin{2};
        obs = varargin{3};
    end
    
    % --- single-frequency cycle-slip detection 
    if settings.OTHER.CS.l1c1
        Epoch = cycleSlip_CLdiff(settings, Epoch, use_column);
    end   
    
    
    % --- dL_i-dL_j cycle-slip detection is enabled 
    if settings.OTHER.CS.DF && (Epoch.q - Epoch.old.q) == 1 && ~isempty(Epoch.old.sats)
        Epoch = cycleSlip_dL(settings, Epoch, use_column);  
    end    
    
   
    % --- cycle-slip detection based on Doppler-Shift
    if settings.OTHER.CS.Doppler && ~isempty(Epoch.old.usable) && Epoch.old.usable == 1
        Epoch = cycleSlip_Doppler(Epoch, use_column, settings);
    end
    
    
    % --- cycle-slip detection based on time-difference of phase observations
    if settings.OTHER.CS.TimeDifference
        Epoch = cycleSlip_TimeDiff(Epoch, use_column, settings);
    end    
    
    % --- cycle-slip detection based on TDCP post-fit residuals
    if isfield(settings.OTHER.CS,'cs_tdcp') && settings.OTHER.CS.cs_tdcp && ~isempty(Epoch.old.sats)
        if ~isempty(input) && ~isempty(obs)
            Epoch = cycleSlip_TDCP(Epoch, settings, input, last_pos, obs);
        end
    end
    
    % --- cycle-slip detection based on averaged HMW LC
    if settings.OTHER.CS.HMW
        Epoch = cycleSlip_HMW(settings, Epoch, use_column);
    end

    % --- check if Loss of Lock Indicator is set in RINEX observation file
    if settings.PROC.LLI
        Epoch = cycleSlip_LLI(Epoch, use_column, settings);
    end

    
    if strcmp(settings.IONO.model, 'Estimate, decoupled clock')
        % ||| check if useful for other PPP models
        % only use observations of satellites with all expected
        % observations because DCM is sensitive to missing observations
        n = settings.INPUT.n_gnss_freqs;
        if n(1) == 3;   n(1) = 2;   end     % do not check GPS L5
        bool_all = check_all_obs(Epoch, n, settings.INPUT.use_GPS, settings.INPUT.use_GLO, settings.INPUT.use_GAL, settings.INPUT.use_BDS, settings.INPUT.use_QZSS);
        Epoch.exclude(~bool_all) = true;
    end
    
    if strcmp(settings.IONO.model, 'Estimate, decoupled clock')
        % DCM is sensitive if (single) phase observations are missing ->
        % exclude satellite completely (although a cycle slip might have
        % been detected on a single frequency only)
        Epoch.cs_found(any(Epoch.cs_found,2), :) = 1;
        Epoch.exclude = Epoch.exclude | Epoch.cs_found;
    end


    % save detected cycle slips in Epoch.sat_status
    Epoch.sat_status(Epoch.cs_found) = 3;
end