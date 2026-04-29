function [Epoch] = cycleSlip(Epoch, settings, use_column, input, last_pos, obs)
% Performs cycle-slip detection. It is possible to insert artificial cycle
% slip into the observations by uncommenting and editing the function 
% cycleSlip_artificial.m (in PPP_main.m)
%
% INPUT:
%   Epoch       struct, epoch-specific data for current epoch
%   settings	struct, settings from GUI
%   use_column	cell, used columns of observation matrix for all GNSS and observation types
% OUTPUT:
%   Epoch       update of .cs_found and added some Cycle-Slip calculations
%  
% Revision:
%   2023/06/11, MFWG: adding QZSS
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

if contains(settings.PROC.method, 'Phase')  % except code only solution
    m = size(Epoch.cs_found, 1);
    nfreq = settings.INPUT.proc_freqs;
    cs_other = false(m, nfreq);
    cs_mw = false(m, nfreq);
    cs_gf = false(m, nfreq);

    % defaults for optional MW+GF settings (keep backward compatibility)
    if ~isfield(settings.OTHER.CS, 'HMW'); settings.OTHER.CS.HMW = false; end
    if ~isfield(settings.OTHER.CS, 'MWGF_enable'); settings.OTHER.CS.MWGF_enable = false; end
    if ~isfield(settings.OTHER.CS, 'MWGF_logic'); settings.OTHER.CS.MWGF_logic = 'AND'; end
    if ~isfield(Epoch, 'cs_found_MW'); Epoch.cs_found_MW = false(m, nfreq); end
    if ~isfield(Epoch, 'cs_found_GF'); Epoch.cs_found_GF = false(m, nfreq); end
    
    
    % --- ||| check cs detection based on HMW LC
    % https://link.springer.com/article/10.1007/s11018-019-01639-5?shared-article-renderer
    
    % --- single-frequency cycle-slip detection 
    if settings.OTHER.CS.l1c1
        Epoch = cycleSlip_CLdiff(settings, Epoch, use_column);
        cs_other = cs_other | Epoch.cs_found;
    end   
    
    
    % --- geometry-free (GF) cycle-slip detection (dL)
    run_df = (settings.OTHER.CS.DF || settings.OTHER.CS.MWGF_enable) && (Epoch.q - Epoch.old.q) == 1 && ~isempty(Epoch.old.sats);
    if run_df
        cs_prev = Epoch.cs_found;
        Epoch = cycleSlip_dL(settings, Epoch, use_column);
        cs_gf = Epoch.cs_found_GF;
        if settings.OTHER.CS.MWGF_enable
            Epoch.cs_found = cs_prev;
        else
            cs_other = cs_other | Epoch.cs_found;
        end
    end    


    % --- Hatch-Melbourne-Wübbena (HMW) cycle-slip detection
    run_hmw = (settings.OTHER.CS.HMW || settings.OTHER.CS.MWGF_enable) && settings.INPUT.proc_freqs > 1;
    if run_hmw
        Epoch = cycleSlip_HMW(settings, Epoch, use_column);
        cs_mw = Epoch.cs_found_MW;
        if ~settings.OTHER.CS.MWGF_enable
            cs_other = cs_other | cs_mw;
        end
    end
    
   
    % --- cycle-slip detection based on Doppler-Shift
    if settings.OTHER.CS.Doppler && ~isempty(Epoch.old.usable) && Epoch.old.usable == 1
        Epoch = cycleSlip_Doppler(Epoch, use_column, settings);
        cs_other = cs_other | Epoch.cs_found;
    end
    
    
    % --- cycle-slip detection based on time-difference of phase observations
    if settings.OTHER.CS.TimeDifference
        Epoch = cycleSlip_TimeDifference(Epoch, use_column, settings);
        cs_other = cs_other | Epoch.cs_found;
    end    
    
    
    % --- cycle-slip detection based on TDCP post-fit residuals
    if isfield(settings.OTHER.CS, 'cs_tdcp') && settings.OTHER.CS.cs_tdcp && isfield(Epoch, 'old')
        Epoch = cycleSlip_TDCP(Epoch, settings, input, last_pos, obs);
        cs_other = cs_other | Epoch.cs_found;
    end
    
    
    % --- check if Loss of Lock Indicator is set in RINEX observation file
    if settings.PROC.LLI
        Epoch = cycleSlip_LLI(Epoch, use_column, settings);
        cs_other = cs_other | Epoch.cs_found;
    end


    % --- combine MW and GF detections if requested
    cs_mwgf = false(m, nfreq);
    if settings.OTHER.CS.MWGF_enable
        if run_hmw && run_df
            if strcmpi(settings.OTHER.CS.MWGF_logic, 'OR')
                cs_mwgf = cs_mw | cs_gf;
            else
                cs_mwgf = cs_mw & cs_gf;
            end
        elseif run_hmw
            cs_mwgf = cs_mw;
        elseif run_df
            cs_mwgf = cs_gf;
        end
    end

    Epoch.cs_found = cs_other | cs_mwgf;
   

    % save detected cycle slips in Epoch.sat_status
    Epoch.sat_status(Epoch.cs_found) = 3;
end