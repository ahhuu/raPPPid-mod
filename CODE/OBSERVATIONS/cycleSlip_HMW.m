function Epoch = cycleSlip_HMW(settings, Epoch, use_column)
% This function performs cycle slip detection based on the
% Hatch-Melbourne-Wübbena linear combination (HMW LC). The algorithm is
% similar than the one described by:
% 
% Blewitt, G. (1990). An Automatic Editing Algorithm for GPS data. 
% Geophysical Research Letters, 17(3), 199–202. 
% https://doi.org/10.1029/GL017i003p00199
% 
% https://gssc.esa.int/navipedia/index.php?title=Detector_based_in_code_and_carrier_phase_data:_The_Melbourne-W%C3%BCbbena_combination
% 
% INPUT:
%   settings        settings of processing from GUI
%   Epoch           struct, epoch-specific data
%   use_column      columns of used observation, from obs.use_column
% OUTPUT:
%   Epoch       updated with detected cycle slips
% 
% Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************



%% Preparations
factor = settings.OTHER.CS.HMW_factor;              % factor for variance threshold []
fixed_thresh = settings.OTHER.CS.HMW_threshold;     % fixed threshold [cycles]
proc_freq = settings.INPUT.proc_freqs;

% get frequencies
f1 = Epoch.f1;
f2 = Epoch.f2;
f3 = Epoch.f3;

% calculate wavelength of WL combinations
% Note: full PRN-space wavelengths are computed after expanding f1/f2/f3.

% get columns of phase observations 
% GPS
l1_gps = use_column{1, 1};      % column of L1 observations in observation matrix (Epoch.obs)
l2_gps = use_column{1, 2};      % column of L2 observations in observation matrix (Epoch.obs)
l3_gps = use_column{1, 3};      % column of L3 observations in observation matrix (Epoch.obs)
% GLONASS
l1_glo = use_column{2, 1}; l2_glo = use_column{2, 2}; l3_glo = use_column{2, 3};
% Galileo
l1_gal = use_column{3, 1}; l2_gal = use_column{3, 2}; l3_gal = use_column{3, 3};
% BeiDou
l1_bds = use_column{4, 1}; l2_bds = use_column{4, 2}; l3_bds = use_column{4, 3};
% QZSS
l1_qzs = use_column{5, 1}; l2_qzs = use_column{5, 2}; l3_qzs = use_column{5, 3};

% get columns of code observations 
% GPS
c1_gps = use_column{1, 4};      % column of C1-observations in observation-matrix (Epoch.obs)
c2_gps = use_column{1, 5};      % column of C2-observations in observation-matrix (Epoch.obs)
c3_gps = use_column{1, 6};      % column of C3-observations in observation-matrix (Epoch.obs)
% GLONASS
c1_glo = use_column{2, 4}; c2_glo = use_column{2, 5}; c3_glo = use_column{2, 6};
% Galileo
c1_gal = use_column{3, 4}; c2_gal = use_column{3, 5}; c3_gal = use_column{3, 6};
% BeiDou
c1_bds = use_column{4, 4}; c2_bds = use_column{4, 5}; c3_bds = use_column{4, 6};
% QZSS
c1_qzs = use_column{5, 4}; c2_qzs = use_column{5, 5}; c3_qzs = use_column{5, 6};

% satellite prns of current epoch
sats = Epoch.sats(:)';  % force row vector to prevent broadcasting
num_sats = numel(sats);
if proc_freq < 2 || num_sats == 0
    Epoch.cs_found_MW = false(num_sats, max(proc_freq, 1));
    return
end

% initialize method-specific result container
Epoch.cs_found_MW = false(num_sats, proc_freq);
gps_now = sats(Epoch.gps);  
glo_now = sats(Epoch.glo);  
gal_now = sats(Epoch.gal);  
bds_now = sats(Epoch.bds);  
qzs_now = sats(Epoch.qzss);  

% expand current epoch frequencies to full PRN space for HMW diagnostics
f1_full = NaN(1, DEF.SATS);   f1_full(sats) = f1;
f2_full = NaN(1, DEF.SATS);   f2_full(sats) = f2;
f3_full = NaN(1, DEF.SATS);   f3_full(sats) = f3;

l_WL_12 = Const.C ./ (f1_full - f2_full);
l_WL_13 = Const.C ./ (f1_full - f3_full);
l_WL_23 = Const.C ./ (f2_full - f3_full);

% observation matrices of current epoch
obs_gps = Epoch.obs(Epoch.gps, :);
obs_glo = Epoch.obs(Epoch.glo, :);
obs_gal = Epoch.obs(Epoch.gal, :);
obs_bds = Epoch.obs(Epoch.bds, :);
obs_qzs = Epoch.obs(Epoch.qzss, :);

% get phase observations of current epoch in [cy]
[L1] = getObs(obs_gps, obs_glo, obs_gal, obs_bds, obs_qzs, l1_gps, l1_glo, l1_gal, l1_bds, l1_qzs, gps_now, glo_now, gal_now, bds_now, qzs_now);
[L2] = getObs(obs_gps, obs_glo, obs_gal, obs_bds, obs_qzs, l2_gps, l2_glo, l2_gal, l2_bds, l2_qzs, gps_now, glo_now, gal_now, bds_now, qzs_now);
[L3] = getObs(obs_gps, obs_glo, obs_gal, obs_bds, obs_qzs, l3_gps, l3_glo, l3_gal, l3_bds, l3_qzs, gps_now, glo_now, gal_now, bds_now, qzs_now);

% get code observations of current epoch in [m]
[C1] = getObs(obs_gps, obs_glo, obs_gal, obs_bds, obs_qzs, c1_gps, c1_glo, c1_gal, c1_bds, c1_qzs, gps_now, glo_now, gal_now, bds_now, qzs_now);
[C2] = getObs(obs_gps, obs_glo, obs_gal, obs_bds, obs_qzs, c2_gps, c2_glo, c2_gal, c2_bds, c2_qzs, gps_now, glo_now, gal_now, bds_now, qzs_now);
[C3] = getObs(obs_gps, obs_glo, obs_gal, obs_bds, obs_qzs, c3_gps, c3_glo, c3_gal, c3_bds, c3_qzs, gps_now, glo_now, gal_now, bds_now, qzs_now);

% in the case of Android raw gnss data processing the phase observations in
% Epoch.obs were already [m] -> convert back to [cy]
if settings.INPUT.rawDataAndroid
    L1(sats) = L1(sats) ./ Epoch.l1(sats)';
    L2(sats) = L2(sats) ./ Epoch.l2(sats)';
    L3(sats) = L3(sats) ./ Epoch.l3(sats)';
end



%% Calculations

% reset HMW cycle slip detection variables for satellites flagged in last epoch
if ~isempty(Epoch.old.cs_found)
    any_old_cs = any(Epoch.old.cs_found, 2);
    reset_prn = Epoch.old.sats(any_old_cs);
    Epoch.cs_HMW_k(:, reset_prn)   = 0;
    Epoch.cs_HMW_av(:, reset_prn)  = 0;
    Epoch.cs_HMW_var(:, reset_prn) = 0;
end


% https://link.springer.com/article/10.1007/s10291-012-0275-7#Sec2
% equation (2), calculate WL ambiguity
N_12 = L1 - L2 - (f1_full.*C1 + f2_full.*C2) ./ (l_WL_12.*(f1_full+f2_full));
N_13 = L1 - L3 - (f1_full.*C1 + f3_full.*C3) ./ (l_WL_13.*(f1_full+f3_full));
N_23 = L2 - L3 - (f2_full.*C2 + f3_full.*C3) ./ (l_WL_23.*(f2_full+f3_full));

% extract values for current epoch satellites only
N_12_curr = reshape(N_12(sats), 1, []);  % force row vector
N_13_curr = reshape(N_13(sats), 1, []);  % force row vector
N_23_curr = reshape(N_23(sats), 1, []);  % force row vector

% increase counter of observed epochs for calculation
Epoch.cs_HMW_k(:, sats) = Epoch.cs_HMW_k(:, sats) + 1;

% get count of current epoch for each combination of frequencies
k12 = Epoch.cs_HMW_k(1, sats);
k13 = Epoch.cs_HMW_k(2, sats);
k23 = Epoch.cs_HMW_k(3, sats);

% get average of WL ambiguity of last epoch
N_12_av_prev = Epoch.cs_HMW_av(1, sats);
N_13_av_prev = Epoch.cs_HMW_av(2, sats);
N_23_av_prev = Epoch.cs_HMW_av(3, sats);

% equation (3a): recursive averaging filter for the WL ambiguity
N_12_ = N_12_av_prev + 1./k12 .* (N_12_curr - N_12_av_prev);
N_13_ = N_13_av_prev + 1./k13 .* (N_13_curr - N_13_av_prev);
N_23_ = N_23_av_prev + 1./k23 .* (N_23_curr - N_23_av_prev);

% get variance of last epoch
var_12_prev = Epoch.cs_HMW_var(1, sats);
var_13_prev = Epoch.cs_HMW_var(2, sats);
var_23_prev = Epoch.cs_HMW_var(3, sats);

% equation (3a): recursive averaging filter for the standard deviation of
% the averaged WL ambiguity
var_12_ = var_12_prev + 1./k12 .* ((N_12_curr - N_12_av_prev).^2 - var_12_prev);
var_13_ = var_13_prev + 1./k13 .* ((N_13_curr - N_13_av_prev).^2 - var_13_prev);
var_23_ = var_23_prev + 1./k23 .* ((N_23_curr - N_23_av_prev).^2 - var_23_prev);

% initialize variances by overwriting (according to navipedia) ||| check this
bool0_12 = (var_12_prev == 0);
bool0_13 = (var_13_prev == 0);
bool0_23 = (var_23_prev == 0);
var_12_(bool0_12) = 0.5;        % because all calculations in [cy]
var_13_(bool0_13) = 0.5;
var_23_(bool0_23) = 0.5;


%% check for cycle slips

% calculate threshold using the defined factor
thresh_fac_12 = factor * sqrt(var_12_);
thresh_fac_13 = factor * sqrt(var_13_);
thresh_fac_23 = factor * sqrt(var_23_);

% create threshold variable
thresh_12 = thresh_fac_12; 
thresh_13 = thresh_fac_13; 
thresh_23 = thresh_fac_23;

% use fixed threshold as replacement for huge thresholds from factor
thresh_12(thresh_12 > fixed_thresh) = fixed_thresh;
thresh_13(thresh_13 > fixed_thresh) = fixed_thresh;
thresh_23(thresh_23 > fixed_thresh) = fixed_thresh;

% do not check satellites, observed the first epoch 
thresh_12(k12 == 1) = Inf;
thresh_13(k13 == 1) = Inf;
thresh_23(k23 == 1) = Inf;

% calculate difference of WL ambiguities to mean
diff_N_12 = reshape(abs(N_12_curr - N_12_av_prev), 1, []);  % force row vector
diff_N_13 = reshape(abs(N_13_curr - N_13_av_prev), 1, []);  % force row vector
diff_N_23 = reshape(abs(N_23_curr - N_23_av_prev), 1, []);  % force row vector

% store diagnostics for plotting/saving
Epoch.cs_WL_12_diff = zeros(1, DEF.SATS);
Epoch.cs_WL_13_diff = zeros(1, DEF.SATS);
Epoch.cs_WL_23_diff = zeros(1, DEF.SATS);
Epoch.cs_var_12 = zeros(1, DEF.SATS);
Epoch.cs_var_13 = zeros(1, DEF.SATS);
Epoch.cs_var_23 = zeros(1, DEF.SATS);
Epoch.cs_WL_12_diff(sats) = diff_N_12;
Epoch.cs_WL_13_diff(sats) = diff_N_13;
Epoch.cs_WL_23_diff(sats) = diff_N_23;
Epoch.cs_var_12(sats) = reshape(var_12_, 1, []);
Epoch.cs_var_13(sats) = reshape(var_13_, 1, []);
Epoch.cs_var_23(sats) = reshape(var_23_, 1, []);

% check for cycle slip
cs_found_12 = (diff_N_12 >= thresh_12);
cs_found_13 = (diff_N_13 >= thresh_13);
cs_found_23 = (diff_N_23 >= thresh_23);

% save detected cycle slips for each frequency
new_cs_found = [...
    cs_found_12' | cs_found_13', ...
    cs_found_12' | cs_found_23', ...
    cs_found_13' | cs_found_23'];

% method-specific output (restricted to processed frequencies)
Epoch.cs_found_MW = new_cs_found(:, 1:proc_freq);


%% save to Epoch

% save new variance
Epoch.cs_HMW_var(1, sats) = var_12_;
Epoch.cs_HMW_var(2, sats) = var_13_;
Epoch.cs_HMW_var(3, sats) = var_23_;

% save new average of WL ambiguity
Epoch.cs_HMW_av(1, sats) = N_12_;
Epoch.cs_HMW_av(2, sats) = N_13_;
Epoch.cs_HMW_av(3, sats) = N_23_;

% save WL ambiguities of current epoch
Epoch.cs_HMW(1, sats) = N_12_curr;
Epoch.cs_HMW(2, sats) = N_13_curr;
Epoch.cs_HMW(3, sats) = N_23_curr;

% check for which satellites the HMW cycle-slip detection has to be 
% resetted (e.g., not-observed, HMW not calculated)
reset_12 = true(DEF.SATS, 1); 
reset_12(sats) = false;         % do not reset observed satellites
reset_13 = reset_12; reset_23 = reset_12;     % initalize
% check if HMW was calculated
% check if HMW was calculated
mask_12 = (isnan(N_12_curr) | N_12_curr == 0);
mask_13 = (isnan(N_13_curr) | N_13_curr == 0);
mask_23 = (isnan(N_23_curr) | N_23_curr == 0);
reset_12(sats) = reset_12(sats) | mask_12(:);
reset_13(sats) = reset_13(sats) | mask_13(:);
reset_23(sats) = reset_23(sats) | mask_23(:);

% reset counter and mean of satellites
Epoch.cs_HMW_k(1, reset_12) = 0; Epoch.cs_HMW_av(1, reset_12) = 0; Epoch.cs_HMW_var(1, reset_12) = 0;
Epoch.cs_HMW_k(2, reset_13) = 0; Epoch.cs_HMW_av(2, reset_13) = 0; Epoch.cs_HMW_var(2, reset_13) = 0;
Epoch.cs_HMW_k(3, reset_23) = 0; Epoch.cs_HMW_av(3, reset_23) = 0; Epoch.cs_HMW_var(3, reset_23) = 0;


%% save detected cycle slips and print to command window
if any(new_cs_found(:))
    % print information of detected cycle slips
    if ~settings.INPUT.bool_parfor
        if any(cs_found_12)
            printCSinfo(cs_found_12, Epoch.sats, diff_N_12, '12', Epoch.q, thresh_12)
        end
        if proc_freq > 2 && any(cs_found_13)
            printCSinfo(cs_found_13, Epoch.sats, diff_N_13, '13', Epoch.q, thresh_13)
        end
        if proc_freq > 2 && any(cs_found_23)
            printCSinfo(cs_found_23, Epoch.sats, diff_N_23, '23', Epoch.q, thresh_23)
        end
    end
end





%% AUXILIARY FUNCTIONS

function [Obs] = getObs(obs_gps, obs_glo, obs_gal, obs_bds, obs_qzss, l_gps, l_glo, l_gal, l_bds, l_qzs, gps, glo, gal, bds, qzs)
% Get code or phase observation for GPS and Galileo for current and last epoch
% INPUT: 
%   obs_gps/glo/...        observation matrix of current epoch
%   l_gps/glo/...          column of observations
%   gps/glo/...            boolean, GPS/... satellites in current epoch
% OUTPUT:
%   Obs         code or phase observation for all GNSS of current epoch

% initialize
Obs = NaN(1,410);
% extract observations
if ~isempty(l_gps)
    Obs(gps) = obs_gps(:,l_gps);      % phase observations of current epoch [cy]
end
if ~isempty(l_glo)
    Obs(glo) = obs_glo(:,l_glo);  
end
if ~isempty(l_gal)
    Obs(gal) = obs_gal(:,l_gal); 
end
if ~isempty(l_bds)
    Obs(bds) = obs_bds(:,l_bds);  
end
if ~isempty(l_qzs)
    Obs(qzs) = obs_qzss(:,l_qzs);  
end
% replace zeros with NaN
Obs(Obs == 0) = NaN;



function [] = printCSinfo(bool_cs, sats, diff_N, str_frq, q, threshs)
% Print out information on detected cycle-slips
prns = sats(bool_cs); values = diff_N(bool_cs); thresh = threshs(bool_cs);
% loop to print
for ii = 1:length(prns)
    fprintf('Cycle-Slip found in HMW LC %s in epoch: %.0f, sat %03.0f: %06.3f (%06.3f) [cy]            \n', ...
        str_frq, q, prns(ii), values(ii), thresh(ii));
end
