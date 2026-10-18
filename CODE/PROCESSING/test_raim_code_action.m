function test_raim_code_action()
old=rng; cleanup=onCleanup(@() rng(old)); %#ok<NASGU>
rng(504); n=30; H=[randn(n,3),ones(n,1)];
E=struct('sats',(1:n)','exclude',false(n,1),'S1',40*ones(n,1),'gps_time',100);
A=struct('A',zeros(2*n,4+n),'Q',eye(2*n),'P',eye(2*n),'omc',zeros(2*n,1),'NO_PARAM',4);
A.A(1:2:end,1:4)=H; A.A(2:2:end,1:4)=H; A.A(2:2:end,5:end)=eye(n);
A.omc(13)=40;
cfg=struct('experiment_action','exclude_code','validation_start_sow',50, ...
    'calibration',struct('global_scale',1,'keys',0,'scales',1), ...
    'pfa_global',1e-3,'downweight_variance_factor',25);
s=struct('PROC',struct('method','Code + Phase','raim',cfg), ...
    'INPUT',struct('proc_freqs',1),'IONO',struct('model','Estimate'));
[out,B]=applyRaimCodeExperiment(E,A,s,45*ones(n,1),1);
assert(out.raim_action.code==1 && out.raim_action.satellite==7);
assert(all(B.A(13,:)==0) && B.omc(13)==0);
assert(isequal(B.A(2:2:end,:),A.A(2:2:end,:)) && isequal(out.exclude,E.exclude));
% Rebuilt matrices receive the same decision in the next iteration.
[~,C]=applyRaimCodeExperiment(out,A,s,45*ones(n,1),2);
assert(isequal(B,C));
% A removed correlated observation must leave the marginal information,
% not the conditional block of the previous inverse covariance.
correlated=A; correlated.Q=eye(2*n)+0.05*ones(2*n);
correlated.P=inv(correlated.Q);
[out,B]=applyRaimCodeExperiment(E,correlated,s,45*ones(n,1),1);
assert(out.raim_action.code==1);
assert(norm(B.P*B.Q-eye(2*n),'fro')<1e-10);
keep=true(2*n,1); keep(13)=false;
assert(norm(B.P(keep,keep)-inv(correlated.Q(keep,keep)),'fro')<1e-10);
% With too little redundancy or multiple unresolved faults, do not act.
small=E; small.sats=(1:4)'; small.S1=40*ones(4,1); small.exclude=false(4,1);
short=A; short.A=A.A(1:8,:); short.Q=eye(8); short.P=eye(8); short.omc=zeros(8,1); short.omc(1)=40;
[out,B]=applyRaimCodeExperiment(small,short,s,45*ones(4,1),1);
assert(out.raim_action.code==0 && isequal(B,short));
multiple=A; multiple.omc(19)=-60;
[out,B]=applyRaimCodeExperiment(E,multiple,s,45*ones(n,1),1);
assert(out.raim_action.code==0 && isequal(B,multiple));
s.PROC.raim.experiment_action='downweight_code';
[out,B]=applyRaimCodeExperiment(E,A,s,45*ones(n,1),1);
assert(out.raim_action.code==2 && isequal(B.A,A.A) && isequal(B.omc,A.omc));
assert(B.Q(13,13)==25 && abs(B.P(13,13)-1/25)<1e-15);
assert(norm(B.P*B.Q-eye(2*n),'fro')<1e-12);
E.gps_time=49;
[~,B]=applyRaimCodeExperiment(E,A,s,45*ones(n,1),1); assert(isequal(A,B));
s.PROC.raim.experiment_action='none'; E.gps_time=100;
[~,B]=applyRaimCodeExperiment(E,A,s,45*ones(n,1),1); assert(isequal(A,B));
fprintf('test_raim_code_action: PASS\n');
end
