function [Epoch,Adjust] = applyRaimCodeExperiment(Epoch,Adjust,settings,elevation,it)
%APPLYRAIMCODEEXPERIMENT Explicitly opt-in, frozen-calibration code-only FDE.
% Select once per epoch; repeat the same action after each matrix rebuild.
% Phase rows, slip flags, ambiguity states and Epoch.exclude are untouched.
cfg=settings.PROC.raim;
if ~isfield(cfg,'experiment_action') || strcmp(cfg.experiment_action,'none'); return; end
assert(any(strcmp(cfg.experiment_action,{'exclude_code','downweight_code'})));
assert(strcmp(settings.PROC.method,'Code + Phase'));
assert(~contains(settings.IONO.model,'decoupled','IgnoreCase',true));
assert(isfield(cfg,'calibration') && isfield(cfg,'validation_start_sow'));
if isfield(cfg,'validation_gps_week') && isfinite(cfg.validation_gps_week) && Epoch.gps_week~=cfg.validation_gps_week
    error('RAIM:CalibrationWeek','RAIM action calibration is bound to another GPS week.');
end
if it==1
    Epoch.raim_action=struct('code',0,'satellite',NaN,'frequency',0, ...
        'row',NaN,'status','before_validation','post_ratio',NaN,'geometry_ratio',NaN);
    if Epoch.gps_time<cfg.validation_start_sow; return; end
    n=numel(Epoch.sats); nf=settings.INPUT.proc_freqs;
    rows=(1:2:2*n*nf)'; H=Adjust.A(rows,1:Adjust.NO_PARAM);
    y=Adjust.omc(rows); Q=Adjust.Q(rows,rows);
    valid=isfinite(y) & any(H~=0,2) & isfinite(diag(Q)) & diag(Q)>0;
    sats=repmat(Epoch.sats(:),nf,1); freq=repelem((1:nf)',n);
    el=repmat(elevation(:,1),nf,1); cn0=NaN(n,nf);
    for f=1:min(3,nf)
        field=sprintf('S%d',f);
        if isfield(Epoch,field) && numel(Epoch.(field))==n; cn0(:,f)=Epoch.(field)(:); end
    end
    cn0=cn0(:); system=floor(sats/100);
    fine=20000+1000*system+100*freq+10*(1+(el>=30)+(el>=60))+(1+(cn0>=30)+(cn0>=40));
    fine(~isfinite(cn0) | ~isfinite(el))=NaN;
    keys=[10000+10*system+freq,fine]; keys=keys(valid,:);
    model=cfg.calibration;
    scale=repmat(model.global_scale,sum(valid),1);
    for level=1:2
        [found,idx]=ismember(keys(:,level),model.keys); scale(found)=model.scales(idx(found));
    end
    trial=raimTrialExclude(y(valid),H(valid,:),Q(valid,valid).*(scale*scale'),cfg.pfa_global);
    Epoch.raim_action.status=trial.status;
    Epoch.raim_action.post_ratio=trial.post_statistic_ratio;
    Epoch.raim_action.geometry_ratio=trial.position_variance_ratio;
    if trial.accepted
        indices=find(valid); j=indices(trial.candidate);
        Epoch.raim_action.row=rows(j);
        Epoch.raim_action.satellite=sats(j); Epoch.raim_action.frequency=freq(j);
        Epoch.raim_action.code=1+strcmp(cfg.experiment_action,'downweight_code');
        Epoch.raim_action.status=cfg.experiment_action;
    end
end
if ~isfield(Epoch,'raim_action') || Epoch.raim_action.code==0; return; end
row=Epoch.raim_action.row;
if Epoch.raim_action.code==1
    % Zero-information dummy row matches raPPPid's existing excluded-row
    % convention while retaining the state and phase observation layout.
    Adjust.A(row,:)=0; Adjust.omc(row)=0;
    Adjust.Q(row,:)=0; Adjust.Q(:,row)=0; Adjust.Q(row,row)=1;
    % Marginalize the removed observation, including correlated covariance.
    Adjust.P=Adjust.Q\eye(size(Adjust.Q));
else
    assert(isfield(cfg,'downweight_variance_factor') && cfg.downweight_variance_factor>=1);
    factor=sqrt(cfg.downweight_variance_factor);
    Adjust.Q(row,:)=Adjust.Q(row,:)*factor; Adjust.Q(:,row)=Adjust.Q(:,row)*factor;
    Adjust.P(row,:)=Adjust.P(row,:)/factor; Adjust.P(:,row)=Adjust.P(:,row)/factor;
end
end
