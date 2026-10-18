function test_raim_code_monitor()
%TEST_RAIM_CODE_MONITOR Deterministic synthetic tests for monitor-only RAIM.

[Epoch, Adjust, settings] = fixture();
[Epoch_ok, d_ok] = raimCodeMonitor(Epoch, Adjust, settings);
assert(isequal(Epoch_ok.exclude, Epoch.exclude), 'Monitor changed exclusion flags.');
assert(d_ok.available && d_ok.pass, 'Clean observations should pass.');
assert(d_ok.dof == 2, 'Unexpected clean-test redundancy.');

Adjust_bad = Adjust;
Adjust_bad.omc(5) = Adjust_bad.omc(5) + 40;
[Epoch_bad, d_bad] = raimCodeMonitor(Epoch, Adjust_bad, settings);
assert(isequal(Epoch_bad.exclude, Epoch.exclude), 'Monitor changed exclusion flags.');
assert(d_bad.available && ~d_bad.pass, 'Injected blunder was not detected.');
assert(d_bad.candidate_satellite == Epoch.sats(5), ...
    'Largest standardized residual identified the wrong satellite.');

Adjust.param_sigma_pred = 4*eye(size(Adjust.A,2));
Adjust_bad.param_sigma_pred = Adjust.param_sigma_pred;
settings.PROC.raim.test_model = 'innovation';
[~, d_nis_ok] = raimCodeMonitor(Epoch, Adjust, settings);
assert(d_nis_ok.available && d_nis_ok.pass, ...
    'Clean innovation should pass when predicted state uncertainty is included.');
[~, d_nis_bad] = raimCodeMonitor(Epoch, Adjust_bad, settings);
assert(d_nis_bad.available && ~d_nis_bad.pass, ...
    'Innovation test did not detect the injected blunder.');

settings.PROC.raim.enable = false;
[Epoch_off, d_off] = raimCodeMonitor(Epoch, Adjust_bad, settings);
assert(~isfield(Epoch_off, 'raim'), 'Disabled monitor should not mutate Epoch.');
assert(~d_off.enabled && strcmp(d_off.status, 'disabled'));
Epoch_next = EpochlyReset_Epoch(Epoch_bad);
assert(~isfield(Epoch_next,'raim'),'RAIM diagnostic leaked across epochs.');

% Translate an OMC linearized at a different state to the prediction.
settings.PROC.raim.enable = true;
Adjust.param = [0.1;0.2;0.3;0;0.4];
Adjust.param_pred = zeros(5,1);
Adjust_shift = Adjust;
Adjust_shift.omc = Adjust.omc + Adjust.A*Adjust.param;
Adjust_shift.param = zeros(5,1);
[~,d1] = raimCodeMonitor(Epoch,Adjust,settings);
[~,d2] = raimCodeMonitor(Epoch,Adjust_shift,settings);
assert(abs(d1.statistic-d2.statistic)<1e-10,'Innovation origin mismatch.');

fprintf('test_raim_code_monitor: PASS\n');
end


function [Epoch, Adjust, settings] = fixture()
Epoch.sats = (1:6)';
Epoch.exclude = false(6,1);

% Six pseudoranges, four estimated terms: dx/dy/dz/common clock.
los = [ ...
    -0.80 -0.10 -0.59; ...
     0.72 -0.35 -0.60; ...
    -0.20  0.91 -0.36; ...
     0.12 -0.84 -0.53; ...
     0.65  0.63 -0.43; ...
    -0.55  0.58 -0.60];
A = zeros(6,5);
A(:,1:3) = los;
A(:,5) = 1;

truth = [0.4; -0.2; 0.1; 1.5];
noise = [0.10; -0.12; 0.08; -0.05; 0.03; -0.04];

Adjust.A = A;
Adjust.omc = A(:,[1 2 3 5]) * truth + noise;
Adjust.Q = eye(6);
Adjust.NO_PARAM = 5;

settings.INPUT.proc_freqs = 1;
settings.PROC.method = 'Code Only';
settings.PROC.raim.enable = true;
settings.PROC.raim.mode = 'monitor_only';
settings.PROC.raim.pfa_global = 1e-3;
settings.PROC.raim.min_redundancy = 1;
end
