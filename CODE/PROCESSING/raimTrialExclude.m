function trial = raimTrialExclude(y,H,Q,pfa)
%RAIMTRIALEXCLUDE Offline one-row FDE proposal, never applied to PPP.
% Requires global failure, Bonferroni local threshold, post-removal global
% pass, retained model rank, >=2 residual DOF and XYZ trace growth <=2.
trial=struct('accepted',false,'candidate',NaN,'status','not_required', ...
    'position_variance_ratio',NaN,'post_statistic_ratio',NaN);
d=raimResidualTest(y,H,Q,pfa,2,'wls_residual');
if ~d.available; trial.status=d.status; return; end
if d.pass; return; end
[score,j]=max(d.standardized_residual,[],'omitnan');
trial.candidate=j;
local_threshold=sqrt(2)*erfcinv(pfa/numel(y));
if score<=local_threshold
    trial.status='local_test_not_significant'; return;
end
keep=true(numel(y),1); keep(j)=false;
post=raimResidualTest(y(keep),H(keep,:),Q(keep,keep),pfa,2,'wls_residual');
if ~post.available || post.n_parameters~=d.n_parameters
    trial.status='insufficient_geometry'; return;
end
trial.post_statistic_ratio=post.statistic/post.threshold;
if ~post.pass; trial.status='post_test_failed'; return; end
before=positionTrace(H,Q); after=positionTrace(H(keep,:),Q(keep,keep));
if ~isfinite(before) || ~isfinite(after) || before<=0
    trial.status='position_not_estimable'; return;
end
trial.position_variance_ratio=after/before;
if trial.position_variance_ratio>2
    trial.status='geometry_degradation'; return;
end
trial.accepted=true; trial.status='shadow_proposal_only';
end

function value=positionTrace(H,Q)
% Check XYZ estimability in the nullspace before using pseudoinverse.
if size(H,2)<3; value=NaN; return; end
B=chol(Q,'lower')\H;
Z=null(B);
if ~isempty(Z) && norm(Z(1:3,:),'fro')>1e-8; value=NaN; return; end
C=pinv(B); value=sum(C(1:3,:).^2,'all');
end
