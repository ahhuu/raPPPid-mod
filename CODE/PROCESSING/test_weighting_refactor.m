%% Unit Test for Weighting Model Refactor
% This script verifies the changes in raPPPid weighting logic.

clear; clc;

% Mock settings
settings.INPUT.num_freqs = 3;
settings.INPUT.proc_freqs = 3;
settings.ADJ.fac_GPS = 1;
settings.ADJ.fac_GLO = 1;
settings.ADJ.fac_GAL = 1;
settings.ADJ.fac_BDS = 1;

% Mock Epoch
Epoch.sats = [1; 2; 3];
Epoch.gps = logical([1; 1; 1]);
Epoch.glo = false(3,1);
Epoch.gal = false(3,1);
Epoch.bds = false(3,1);
Epoch.qzss = false(3,1);
Epoch.S1 = [30; 40; 50];
Epoch.S2 = [32; 42; 52];
Epoch.S3 = [35; 45; 55];

% Mock Elevation
elev = [30; 60; 90]; % Degrees

fprintf('Starting Unit Tests...\n\n');

%% Test 1: Unified Elevation Weighting (Backward Compatibility)
fprintf('Test 1: Unified Elevation Weighting... ');
settings.ADJ.weight_elev = 1;
settings.ADJ.weight_mplc = 0;
settings.ADJ.weight_sign_str = 0;
settings.ADJ.weight_snr_elev = 0;
settings.ADJ.weight_none = 0;
settings.ADJ.elev_weight_fun = @(e) sin(e).^2;

P = createWeights(Epoch, elev, settings);
assert(all(abs(P(:,1) - sin(elev*pi/180).^2) < 1e-6));
assert(all(abs(P(:,1) - P(:,2)) < 1e-6));
fprintf('PASSED\n');

%% Test 2: Frequency-specific Elevation Weighting
fprintf('Test 2: Frequency-specific Elevation Weighting... ');
settings.ADJ.elev_weight_fun = {@(e) sin(e).^2, @(e) sin(e), @(e) ones(size(e))};

P = createWeights(Epoch, elev, settings);
assert(all(abs(P(:,1) - sin(elev*pi/180).^2) < 1e-6));
assert(all(abs(P(:,2) - sin(elev*pi/180)) < 1e-6));
assert(all(abs(P(:,3) - 1) < 1e-6));
fprintf('PASSED\n');

%% Test 3: Frequency-specific SNR Weighting
fprintf('Test 3: Frequency-specific SNR Weighting... ');
settings.ADJ.weight_elev = 0;
settings.ADJ.weight_sign_str = 1;
% Formula: 1./(61.8629-1435.4351.*10.^(-SNR/10))
custom_formula = @(SNR) 1./(61.8629-1435.4351.*10.^(-SNR/10));
settings.ADJ.snr_weight_fun = {custom_formula, @(SNR) SNR/100, @(SNR) ones(size(SNR))};

P = createWeights(Epoch, elev, settings);
assert(all(abs(P(:,1) - custom_formula(Epoch.S1)) < 1e-6));
assert(all(abs(P(:,2) - Epoch.S2/100) < 1e-6));
assert(all(abs(P(:,3) - 1) < 1e-6));
fprintf('PASSED\n');

%% Test 4: Combined SNR/Elevation Weighting
fprintf('Test 4: Combined Weighting... ');
settings.ADJ.weight_sign_str = 0;
settings.ADJ.weight_snr_elev = 1;
settings.ADJ.snr_elev_weight_fun = {@(SNR, e) SNR/100 .* sin(e), @(SNR, e) ones(size(SNR))};

P = createWeights(Epoch, elev, settings);
w1_expected = (Epoch.S1/100) .* sin(elev*pi/180);
assert(all(abs(P(:,1) - w1_expected) < 1e-6));
assert(all(abs(P(:,2) - 1) < 1e-6));
% Column 3 should reuse index 1 because of mod(j-1, L)+1
w3_expected = (Epoch.S3/100) .* sin(elev*pi/180);
assert(all(abs(P(:,3) - w3_expected) < 1e-6));
fprintf('PASSED\n');

%% Test 5: System-specific Weighting (GPS vs GAL)
fprintf('Test 5: System-specific Weighting... ');
settings.ADJ.weight_snr_elev = 0;
settings.ADJ.weight_elev = 1;

% Mock Epoch with different systems
Epoch.sats = [1; 21; 31]; % G01, E01, C01
Epoch.gps = logical([1; 0; 0]);
Epoch.gal = logical([0; 1; 0]);
Epoch.bds = logical([0; 0; 1]);
Epoch.glo = false(3,1);
Epoch.qzss = false(3,1);

% GPS: sin(e)^2; GAL: sin(e); default: 1
settings.ADJ.elev_weight_fun = struct();
settings.ADJ.elev_weight_fun.GPS = {@(e) sin(e).^2};
settings.ADJ.elev_weight_fun.GAL = {@(e) sin(e)};
settings.ADJ.elev_weight_fun.default = {@(e) 1};

P = createWeights(Epoch, elev, settings);

% G01 should use GPS formula
assert(abs(P(1,1) - sin(elev(1)*pi/180)^2) < 1e-6);
% E01 should use GAL formula
assert(abs(P(2,1) - sin(elev(2)*pi/180)) < 1e-6);
% C01 should use default formula
assert(abs(P(3,1) - 1) < 1e-6);
fprintf('PASSED\n');

%% Test 6: Parser Logic Verification
fprintf('Test 6: Parser Logic Verification... ');
% Test Elevation Parser with complex prefix string
funstring = '1; GPS: sin(e)^2; GAL: sin(e)';
fh = ElevationWeightingFunction(funstring);
assert(isstruct(fh));
assert(isfield(fh, 'GPS') && iscell(fh.GPS) && numel(fh.GPS) == 1);
assert(isfield(fh, 'GAL') && iscell(fh.GAL) && numel(fh.GAL) == 1);
assert(isfield(fh, 'default') && iscell(fh.default) && numel(fh.default) == 1);

% Test SNR Parser with prefixes and options
funstring = 'sin(SNR); G: option_1; E: SNR/100';
fh = SNRWeightingFunction(funstring);
assert(isstruct(fh));
assert(strcmp(fh.GPS{1}, 'option_1'));
assert(isa(fh.GAL{1}, 'function_handle'));
assert(isa(fh.default{1}, 'function_handle'));
fprintf('PASSED\n');

fprintf('\nAll Unit Tests (Frequency & System) Passed Successfully!\n');

% Unprefixed formulas after a system prefix are additional frequencies.
fh=ElevationWeightingFunction('G: sin(e); sin(e)^2');
assert(numel(fh.GPS)==2);
fh=SNR_ElevationWeightingFunction('@(SNR,e) SNR/100.*sin(e)');
assert(abs(fh(30,pi/2)-0.3)<1e-12);
