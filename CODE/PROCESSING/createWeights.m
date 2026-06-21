function P_diag = createWeights(Epoch, elev, settings, bore)
% Function to create the weights of the observations for the diagonal of
% the weighting matrix P or, in other words, the weight factors for the
% variance of the observations.
% Variants:
% -) weight the observations depending on the procedure described in [02]
% -) weight the observations depending on the elevation of their satellites
% -) weight the observations depending on their signal strength on 1st frequency
%
% INPUT:
%   Epoch           containing epoch-specific data
%   elev            elevation to GNSS satellites of current epoch [�]
%   settings        setting of proceesing from GUI
%   bore            boresight angle to GNSS satellites of current epoch [�]
% OUTPUT:
%   P_diag          [n sats x input freqs], weight for each satellite and frequency
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************

persistent diagnostic_printed;
if isempty(diagnostic_printed)
    diagnostic_printed = false;
end

num_freq = settings.INPUT.num_freqs;        % number of input frequencies
n_sats = numel(Epoch.sats);                 % # sats in current epoch
P_diag = ones(n_sats,num_freq);
elev = elev*pi/180; 	% elevation of satellites of this epoch [rad]
elev_n = repmat(elev(:,1),1,num_freq);      % elevation is equal on all frequencies



% --- Weighting depending on combination of elevation and MP-LC, check [02]
if settings.ADJ.weight_mplc
    if Epoch.q > 5
        w1 = tanh((Epoch.mp1_var.^-1)/100)' + sin(elev);
        w2 = tanh((Epoch.mp2_var.^-1)/100)' + sin(elev);
        w = (w1+w2)/2;
        % variance = NaN (e.g. satellite is not observed for 5 epochs),
        % weight according to sqrt(elevation)
        w(isnan(w)) = sqrt(elev(isnan(w)));
        P_diag(:,1) = w;
        P_diag(:,2) = w;
    else        % not enough epochs to calculate variance so weight depending on elevation
        P_diag = sin(elev_n).^2;
    end


    % --- Weighting according to elevation
elseif settings.ADJ.weight_elev
    % observations on different frequencies get same weight factor
    if isa(settings.ADJ.elev_weight_fun, 'function_handle')
        P_diag(:,:) = settings.ADJ.elev_weight_fun(elev_n);
    elseif strcmp(settings.ADJ.elev_weight_fun, 'option_0')
        P_diag = sin(elev_n).^2;        % option_0 is sin(e)^2
    else
        fprintf(2, '\nError in createWeights!\n')
    end


    % --- No weighting of the observations
elseif settings.ADJ.weight_none
    P_diag(:,:) = 1;


% --- Weighting using signal to noise ratio (e.g., low-cost equipment), check [05]
elseif settings.ADJ.weight_sign_str
    if ischar(settings.ADJ.snr_weight_fun)
        % hardcoded C/N0 weighting function
        switch settings.ADJ.snr_weight_fun
            case 'option_1'
                if ~isempty(Epoch.S1)
                    P_diag = goGPS_SNR_weighting(P_diag, Epoch.S1, 1);
                end
                if ~isempty(Epoch.S2) && settings.INPUT.proc_freqs >= 2
                    P_diag = goGPS_SNR_weighting(P_diag, Epoch.S2, 2);
                end
                if ~isempty(Epoch.S3) && settings.INPUT.proc_freqs >= 3
                    P_diag = goGPS_SNR_weighting(P_diag, Epoch.S3, 3);
                end
            case 'option_0'
                % option_0 = 10.^-(max([55-snr,0])./10)
                SNR = [Epoch.S1, Epoch.S2, Epoch.S3];
                expo = 55 - SNR;
                expo(expo < 0 | isnan(expo)) = 0;
                expo = expo ./ 10;
                P_diag = 10 .^ -expo;
            otherwise
                fprintf(2, '\nError in createWeights!\n')
        end
    elseif isa(settings.ADJ.snr_weight_fun, 'function_handle')
        % C/N0 weighting function from GUI (user input)
        SNR = [Epoch.S1, Epoch.S2, Epoch.S3];
        if contains(func2str(settings.ADJ.snr_weight_fun), 'max(')
            % function-handle does not work with max()-function and vector
            for i = 1:n_sats         % ||| more elegant solution than a loop?
                for j = 1:num_freq
                    P_diag(i,j) = settings.ADJ.snr_weight_fun(SNR(i,j));
                end
            end
        else
            P_diag(:,:) = settings.ADJ.snr_weight_fun(SNR);
            if settings.INPUT.proc_freqs >= 2
                % replace missing values
                P_diag_1 = P_diag(:,1);
                P_diag_2 = P_diag(:,2);
                bool = isnan(P_diag_2) | P_diag_2 == 0;
                P_diag_2(bool) = P_diag_1(bool);
                P_diag(:,2) = P_diag_2;
            end
            if settings.INPUT.proc_freqs >= 3
                % replace missing values
                P_diag_3 = P_diag(:,3);
                bool = isnan(P_diag_3) | P_diag_3 == 0;
                P_diag_3(bool) = P_diag_1(bool);
                P_diag(:,3) = P_diag_3;
            end
        end
    end
    % ||| check for multi-frequency processing
    % ||| check for IF LC (which S1 to take?)


elseif settings.ADJ.weight_snr_elev
    % --- Weighting depending on a combination of SNR and elevation ---
    SNR = [Epoch.S1, Epoch.S2, Epoch.S3];
    for i = 1:n_sats
        funs = getFunctionsForSat(i, Epoch, settings.ADJ.snr_elev_weight_fun);
        for j = 1:num_freq
            fun = funs{mod(j-1, numel(funs))+1};
            P_diag(i,j) = calculateCombinedWeight(fun, SNR(i,j), elev_n(i,j));
        end
    end
    % Handle outliers and missing values
    for j = 1:num_freq
        invalid_idx = isnan(SNR(:,j)) | isnan(elev_n(:,j)) | P_diag(:,j) <= 0;
        P_diag(invalid_idx,j) = 1e-6;
        P_diag(:,j) = max(min(P_diag(:,j), 1e6), 1e-6);
    end
    if settings.INPUT.proc_freqs >= 2
        replace_idx = isnan(SNR(:,2)) | P_diag(:,2) <= 1e-6;
        P_diag(replace_idx,2) = P_diag(replace_idx,1);
    end
    if settings.INPUT.proc_freqs >= 3
        replace_idx = isnan(SNR(:,3)) | P_diag(:,3) <= 1e-6;
        P_diag(replace_idx,3) = P_diag(replace_idx,1);
    end


elseif settings.ADJ.weight_bore
    % --- Weighting according to antenna boresight angle
    bore(isnan(bore)) = 0;                  % might happen in first epoch
    w = (1 + cos(pi * bore / 180)) / 2;     % w = 1 for 0�, w = 0 for 180�
    P_diag = repmat(w, 1, num_freq);



    % --- No weighting of the observations
end

% --- GNSS weighting% --- GNSS weighting
P_diag(Epoch.gps,:) = P_diag(Epoch.gps,:) / settings.ADJ.fac_GPS;
P_diag(Epoch.glo,:) = P_diag(Epoch.glo,:) / settings.ADJ.fac_GLO;
P_diag(Epoch.gal,:) = P_diag(Epoch.gal,:) / settings.ADJ.fac_GAL;
P_diag(Epoch.bds,:) = P_diag(Epoch.bds,:) / settings.ADJ.fac_BDS;

% very low weigth for weights which are NaN, zero, or negative
P_diag(isnan(P_diag)) = 10^-6;
P_diag(P_diag <= 0) = 10^-6;

% --- Terminal output: random-model weighting only ---
try
    if isfield(Epoch, 'q') && isfield(settings, 'PROC') && isfield(settings.PROC, 'epochs') && ...
       Epoch.q == settings.PROC.epochs(2) && ~diagnostic_printed
        fprintf('\n%s [raPPPid] Final Weighting Configuration Summary %s\n', repmat('=',1,15), repmat('=',1,15));
        fprintf('%-8s | %-4s | %-6s | %-10s | %-30s | %-10s\n', 'Sat', 'Sys', 'Freq', 'Value', 'Formula', 'Weight');
        fprintf('%s\n', repmat('-', 95));
        for i = 1:n_sats
            prn = Epoch.sats(i);
            if Epoch.gps(i)
                sys = 'GPS';
            elseif Epoch.glo(i)
                sys = 'GLO';
            elseif Epoch.gal(i)
                sys = 'GAL';
            elseif Epoch.bds(i)
                sys = 'BDS';
            else
                sys = 'OTHER';
            end
            if settings.ADJ.weight_elev
                fun_setting = settings.ADJ.elev_weight_fun;
            elseif settings.ADJ.weight_sign_str
                fun_setting = settings.ADJ.snr_weight_fun;
            elseif settings.ADJ.weight_snr_elev
                fun_setting = settings.ADJ.snr_elev_weight_fun;
            elseif settings.ADJ.weight_mplc
                fun_setting = {@(x) x};
            else
                fun_setting = {@(x) 1};
            end
            funs = getFunctionsForSat(i, Epoch, fun_setting);
            for j = 1:num_freq
                fun = funs{mod(j-1, numel(funs))+1};
                if settings.ADJ.weight_elev
                    val_str = sprintf('%.1f deg', elev(i,1) * 180/pi);
                elseif settings.ADJ.weight_sign_str
                    SNR_vals = [Epoch.S1, Epoch.S2, Epoch.S3];
                    val_str = sprintf('%.1f dBHz', SNR_vals(i,j));
                elseif settings.ADJ.weight_snr_elev
                    SNR_vals = [Epoch.S1, Epoch.S2, Epoch.S3];
                    val_str = sprintf('S%.0f, E%.0f', SNR_vals(i,j), elev(i,1) * 180/pi);
                elseif settings.ADJ.weight_mplc
                    val_str = sprintf('%.1f', elev(i,1) * 180/pi);
                else
                    val_str = 'N/A';
                end
                if ischar(fun)
                    fun_str = fun;
                else
                    fun_str = func2str(fun);
                end
                fprintf('%-8d | %-4s | %-6d | %-10s | %-30s | %-10.4f\n', prn, sys, j, val_str, fun_str, P_diag(i,j));
            end
        end
        fprintf('%s\n\n', repmat('=', 45));
        diagnostic_printed = true;
    end
catch
    % ignore output failures
end

end





function w = calculateCombinedWeight(fun, SNR, elev)
% Helper to calculate combined SNR/elevation weights with vectorized or scalar function handles
try
    w = fun(SNR, elev);
catch
    w = zeros(size(SNR));
    for ii = 1:numel(SNR)
        w(ii) = fun(SNR(ii), elev(ii));
    end
end
end


function funs = getFunctionsForSat(sat_idx, Epoch, fun_setting)
% Get weighting functions for a single satellite from system-specific settings
if isstruct(fun_setting)
    if isfield(Epoch, 'gps') && Epoch.gps(sat_idx)
        sys = 'GPS';
    elseif isfield(Epoch, 'glo') && Epoch.glo(sat_idx)
        sys = 'GLO';
    elseif isfield(Epoch, 'gal') && Epoch.gal(sat_idx)
        sys = 'GAL';
    elseif isfield(Epoch, 'bds') && Epoch.bds(sat_idx)
        sys = 'BDS';
    elseif isfield(Epoch, 'qzss') && Epoch.qzss(sat_idx)
        sys = 'QZSS';
    else
        sys = 'default';
    end
    if isfield(fun_setting, sys)
        funs = fun_setting.(sys);
    elseif isfield(fun_setting, 'default')
        funs = fun_setting.default;
    else
        fields = fieldnames(fun_setting);
        funs = fun_setting.(fields{1});
    end
elseif iscell(fun_setting)
    funs = fun_setting;
else
    funs = {fun_setting};
end
end


function P_diag = goGPS_SNR_weighting(P_diag, SNR, frq)
% Creating weights depending on Carrier-to-Noise density following [05]: (5.1)
%
% INPUT:
%   P_diag      values for diagonal of weight matrix P
%   C/N0        Carrier-to-Noise Density of current frequency
%   frq         frequency or column of P_diag which should be manipulated
% OUTPUT:
%   P_diag      calculated weights added
% *************************************************************************

% some constants
a = 30;         % defines bending of the curve
s_1 = 50;       % C/N0 > this threshold, weight = 1
s_0 = 20;       % defines C/N0 where function is forced to have the weight defined by A
A = 30;     	% ... however, 1/is used here already
% calculate weights
q_R = 10.^(-(SNR-s_1)/a) .* ( (A/10.^(-(s_0-s_1)/a)-1)./(s_0-s_1).*(SNR-s_1)+1 );
P_diag(:,frq) = P_diag(:,frq) ./ q_R;        	% weight for observations
P_diag(SNR >= s_1, frq) = 1;                    % 1 for C/N0 > snr_1

end
