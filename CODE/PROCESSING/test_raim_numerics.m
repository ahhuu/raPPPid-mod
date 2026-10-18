function test_raim_numerics()
%TEST_RAIM_NUMERICS Independent Gaussian/analytic covariance checks.
old_rng = rng; cleanup = onCleanup(@() rng(old_rng)); %#ok<NASGU>
rng(20261005);
n = 12; H = [ones(n,1),randn(n,3)];
Q = diag(linspace(1,4,n)); y = randn(n,1);
d = raimResidualTest(y,H,Q,0.01,1,'wls_residual');
W = diag(1./diag(Q));
v = H*((H'*W*H)\(H'*W*y))-y;
assert(abs(d.statistic-v'*W*v)<1e-10);
scaled = raimResidualTest(y,H*diag([1e-8 1e8 1e-4 1e4]),Q,0.01,1,'wls_residual');
assert(abs(d.statistic-scaled.statistic)<1e-10 && scaled.dof == n-4);
draws = chol(Q,'lower')*randn(n,20000);
v = d.residual_operator*draws;
T = sum((chol(Q,'lower')\v).^2,1);
rate = mean(T>d.threshold);
assert(rate>0.007 && rate<0.013,'Gaussian WLS false alarm is miscalibrated.');

% Huge uncertain common clock can hide a fault in marginal z scores;
% the joint test and conditional score must still expose a differential fault.
S = eye(n)+1e8*ones(n);
fault = zeros(n,1); fault(5) = 40;
d = raimResidualTest(fault,H,S,0.001,1,'innovation');
expected = fault'*fault - (sum(fault)^2)/(n+1e-8);
assert(d.available && ~d.pass && abs(d.statistic/expected-1)<1e-6);
[~,candidate] = max(d.standardized_residual);
assert(candidate==5 && max(abs(fault)./sqrt(diag(S)))<0.01);
bad = eye(n); bad(1,2)=2; bad(2,1)=2;
d = raimResidualTest(y,H,bad,0.001,1,'innovation');
assert(~d.available && strcmp(d.status,'invalid_covariance'));
d = raimResidualTest(y,eye(n),Q,0.001,1,'wls_residual');
assert(~d.available && strcmp(d.status,'insufficient_redundancy'));
% Correlated WLS local score matches the original-observation fault model.
Q=diag(linspace(1,4,n))+0.4*ones(n);
d=raimResidualTest(y,H,Q,0.001,1,'wls_residual');
W=Q\eye(n); P=W-W*H*((H'*W*H)\(H'*W));
assert(norm(d.standardized_residual-abs(P*y)./sqrt(diag(P)))<1e-9);

% One-row shadow FDE must re-test and recover a known isolated fault.
H=[randn(30,3),ones(30,1)]; clean=zeros(30,1); dirty=clean; dirty(7)=40;
proposal=raimTrialExclude(dirty,H,eye(30),1e-3);
assert(proposal.accepted && proposal.candidate==7);
proposal=raimTrialExclude(clean,H,eye(30),1e-3);
assert(~proposal.accepted && strcmp(proposal.status,'not_required'));
dirty(15)=-40;
proposal=raimTrialExclude(dirty,H,eye(30),1e-3);
assert(~proposal.accepted,'Multiple faults must not pass a single-removal test.');
fprintf('test_raim_numerics: PASS; Gaussian false_alarm=%.4f (target=0.01)\n',rate);
end
