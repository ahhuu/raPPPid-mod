function test_code_snr_f2_weighting()
% Regression tests for frequency-2 raw-code SNR standard deviations.

settings.ADJ.code_snr_f2 = struct( ...
    'enable', true, 'low_snr', 30, 'high_snr', 40, ...
    'low_std', 2.0, 'missing_snr', 'base', ...
    'systems', struct('GPS',true,'GLO',false,'GAL',true, ...
                      'BDS',true,'QZSS',false));

Epoch.S2 = [25; 35; 45; NaN];
Epoch.gps  = logical([1; 1; 0; 0]);
Epoch.glo  = false(4,1);
Epoch.gal  = logical([0; 0; 1; 0]);
Epoch.bds  = logical([0; 0; 0; 1]);
Epoch.qzss = false(4,1);

base_sigma = [0.18; 0.18; 0.10; 0.10];
VAR_code = repmat(base_sigma.^2, 1, 3);
VAR_before = VAR_code;
[VAR_after, sigma_f2] = applyCodeSnrF2Std(VAR_code, Epoch, settings);

assert(max(abs(VAR_after(:,1) - VAR_before(:,1))) == 0);
assert(max(abs(VAR_after(:,3) - VAR_before(:,3))) == 0);
assert(abs(sigma_f2(1) - 2.0) < 1e-12);
assert(abs(sigma_f2(2) - 1.09) < 1e-12);
assert(abs(sigma_f2(3) - 0.10) < 1e-12);
assert(abs(sigma_f2(4) - 0.10) < 1e-12);

% Verify the uncombined covariance flattening order remains
% C1,L1,C1,L1,...,C2,L2,... and only C2 entries change.
phase_var = reshape(101:112, 4, 3);
fac_before = [VAR_before(:)'; phase_var(:)']; fac_before = fac_before(:);
fac_after  = [VAR_after(:)';  phase_var(:)']; fac_after  = fac_after(:);
changed = find(abs(fac_after - fac_before) > 0);
expected = 2*size(VAR_code,1) + 2*(1:size(VAR_code,1)) - 1;
expected = expected([1 2]); % GAL is already at its high-SNR base; BDS SNR is missing.
assert(isequal(changed(:)', expected));
assert(all(fac_after(2:2:end) == fac_before(2:2:end))); % every phase variance

settings.ADJ.code_snr_f2.missing_snr = 'low';
[~, sigma_missing_low] = applyCodeSnrF2Std(VAR_code, Epoch, settings);
assert(abs(sigma_missing_low(4) - 2.0) < 1e-12);

% Saved GUI settings commonly use an explicit handle without a space
% between arguments. It must survive parsing and round-tripping.
combined = SNR_ElevationWeightingFunction( ...
    '@(SNR,e)1./(0.0254./sin(e).^2+2207.3209.*10.^(-SNR/10))');
assert(isa(combined, 'function_handle'));
assert(isfinite(combined(35, 30*pi/180)));

fprintf('Frequency-2 code SNR weighting tests PASSED.\n');
end
