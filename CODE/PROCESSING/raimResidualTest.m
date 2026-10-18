function d = raimResidualTest(y, H, Q, pfa, min_dof, test_model)
%RAIMRESIDUALTEST Covariance-whitened test; no PPP state changes.
% WLS uses an SVD projection, avoiding normal-equation conditioning.
% Innovation uses the conditional single-observation score |W*y|/sqrt(Wii).
% Invalid/non-SPD covariance is unavailable, never silently regularized.
y = double(y(:)); H = double(H); Q = double(Q);
n = numel(y);
d = struct('available',false,'pass',false,'status','invalid_covariance', ...
    'statistic',NaN,'threshold',NaN,'dof',0,'n_parameters',0, ...
    'residual_m',[],'standardized_residual',[], ...
    'covariance_rcond',NaN,'score_operator',[],'residual_operator',[]);
if ~isequal(size(Q),[n n]) || size(H,1) ~= n || n == 0 || ...
        any(~isfinite(Q(:))) || any(~isfinite(H(:))) || any(~isfinite(y))
    return;
end
Q = (Q+Q')/2;
scale = sqrt(diag(Q));
if any(~isfinite(scale) | scale <= 0); return; end
C = Q ./ (scale*scale');
[Lc, flag] = chol((C+C')/2,'lower');
d.covariance_rcond = rcond(C);
if flag ~= 0; return; end
if d.covariance_rcond < 1e-14
    d.status = 'ill_conditioned_covariance';
    return;
end
L = scale .* Lc;
z = L\y;
if strcmpi(test_model,'wls_residual')
    B = L\H;
    norms = sqrt(sum(B.^2,1));
    B = B(:,norms>0) ./ norms(norms>0);
    [U,s,~] = svd(B,'econ');
    sv = diag(s);
    r = 0;
    if ~isempty(sv); r = sum(sv > max(size(B))*eps(max(sv))); end
    U = U(:,1:r);
    R = eye(n)-U*U';
    d.n_parameters = r;
    d.dof = n-r;
    d.residual_operator = -L*R/L;
    d.residual_m = d.residual_operator*y;
    % Score for a fault in original observation j, valid also for correlated Q.
    % With diagonal Q this equals |v_j|/sqrt(Qvv_jj).
    information = (L'\R)/L;
    info_diag = diag(information);
    evaluable = info_diag > max(info_diag)*1e-12;
    d.score_operator = zeros(n);
    d.score_operator(evaluable,:) = ...
        information(evaluable,:) ./ sqrt(info_diag(evaluable));
    d.standardized_residual = abs(d.score_operator*y);
    d.standardized_residual(~evaluable) = NaN;
    d.statistic = sum((R*z).^2);
elseif strcmpi(test_model,'innovation')
    Linv = L\eye(n);
    W = Linv'*Linv;
    d.dof = n;
    d.n_parameters = 0; % no parameters fitted to this epoch's innovation
    d.residual_operator = eye(n);
    d.residual_m = y;
    d.score_operator = W ./ sqrt(diag(W));
    d.standardized_residual = abs(d.score_operator*y);
    d.statistic = sum(z.^2);
else
    d.status = 'unsupported_test_model';
    return;
end
if d.dof < min_dof
    d.status = 'insufficient_redundancy';
    return;
end
d.threshold = 2*gammaincinv(1-pfa,d.dof/2);
d.available = isfinite(d.statistic) && d.statistic >= 0;
d.pass = d.available && d.statistic <= d.threshold;
if d.pass; d.status = 'pass'; else; d.status = 'fault_detected'; end
end
