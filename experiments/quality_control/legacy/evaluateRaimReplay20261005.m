function report = evaluateRaimReplay20261005(manifest_file)
%EVALUATERAIMREPLAY20261005 Chronological calibration and injection evidence.
% Real unmodified shaded data are NOT labeled fault free: their alarm rate
% is not a measured false-alarm rate. Gaussian trials separately test the
% assumed model with real geometry, not real-world integrity performance.
M = load(manifest_file,'manifest'); manifest = M.manifest;
folder = fileparts(manifest_file);
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
out = fullfile(folder,['evidence_' stamp]); mkdir(out);
old_rng = rng; cleanup = onCleanup(@() rng(old_rng)); %#ok<NASGU>
rng(20261005);
summary_rows = {}; injection_rows = {}; group_rows = {}; audit_rows = {}; shadow_rows = {};
for device_index = 1:height(manifest)
    device = char(manifest.device(device_index));
    source = char(manifest.output_dir(device_index));
    files = dir(fullfile(source,'raim_replay','epoch_*.mat'));
    assert(numel(files)>=6,'Too few captured epochs for %s.',device);
    frames = cell(numel(files),1); times = NaN(numel(files),1);
    for k = 1:numel(files)
        B = load(fullfile(files(k).folder,files(k).name),'snapshot'); s = B.snapshot;
        frames{k} = compactFrame(s); times(k) = s.gps_time;
        config = s.settings;
        config.PROC.raim.test_model = 'innovation';
        [~, innovation] = raimCodeMonitor(s.Epoch,s.Adjust,config);
        audit_rows(end+1,:) = {device,s.epoch,innovation.available, ... %#ok<AGROW>
            innovation.status,innovation.covariance_rcond,innovation.statistic, ...
            innovation.threshold,innovation.max_standardized_residual};
    end
    split = (min(times)+max(times))/2;
    train = find(times < split-30);
    validation = find(times > split+30);
    assert(~isempty(train) && ~isempty(validation),'Need a longer time span.');
    training_rows = [];
    for k = train'
        f = frames{k};
        d = raimResidualTest(f.y,f.H,f.Q,1e-3,1,'wls_residual');
        if ~d.available; continue; end
        training_rows = [training_rows; f.keys, d.standardized_residual]; %#ok<AGROW>
    end
    model = fitScales(training_rows);
    for g = 1:numel(model.keys)
        group_rows(end+1,:) = {device,model.keys(g),model.counts(g),model.scales(g)}; %#ok<AGROW>
    end
    % A global fallback is explicitly included in the persisted model.
    save(fullfile(out,[device '_calibration.mat']),'model','train','validation', ...
        'times','source','manifest_file');
    for variant = {'nominal','empirical_grouped'}
        label = variant{1};
        n_eval = 0; n_alarm = 0; dofs = []; ratios = [];
        % Rows: no fault, 5,10,20,40m; columns: trials, global alarm,
        % correct localization AND alarm, previously passing trials,
        % new alarms among previously passing trials.
        real_counts = zeros(5,5); gaussian_counts = zeros(5,5);
        for k = validation'
            f = frames{k}; Q = f.Q;
            if strcmp(label,'empirical_grouped')
                sigma_scale = predictScales(model,f.keys);
                Q = Q .* (sigma_scale*sigma_scale');
            end
            d = raimResidualTest(f.y,f.H,Q,1e-3,1,'wls_residual');
            if ~d.available; continue; end
            n_eval = n_eval+1; n_alarm = n_alarm+~d.pass;
            dofs(end+1) = d.dof; ratios(end+1) = d.statistic/d.threshold; %#ok<AGROW>
            L = chol(Q,'lower');
            T_operator = L\d.residual_operator;
            real_counts = real_counts + injectTrials(f.y,T_operator,d.score_operator,d.threshold);
            % One-row FDE proposals on real data and deterministic injected
            % targets. No proposal is fed back into the actual PPP filter.
            j = 1+mod(k-1,numel(f.y));
            for delta = [0 -10 10 -40 40]
                changed = f.y; changed(j)=changed(j)+delta;
                trial = raimTrialExclude(changed,f.H,Q,1e-3);
                target = NaN; correct = NaN;
                if delta~=0; target=j; correct=trial.accepted && trial.candidate==j; end
                shadow_rows(end+1,:)={device,label,k,delta,target,trial.accepted, ... %#ok<AGROW>
                    trial.candidate,correct,trial.status,trial.position_variance_ratio, ...
                    trial.post_statistic_ratio};
            end
            % 50 independent draws per validation geometry, same covariance
            % as tested. Only this series has a known fault-free null.
            synthetic = L*randn(numel(f.y),50);
            gaussian_counts = gaussian_counts + injectTrials(synthetic,T_operator,d.score_operator,d.threshold);
        end
        summary_rows(end+1,:) = {device,label,numel(train),numel(validation), ... %#ok<AGROW>
            n_eval,n_alarm,100*n_alarm/max(1,n_eval),median(dofs),median(ratios), ...
            model.global_scale};
        for kind = {'real_shaded','matched_gaussian'}
            if strcmp(kind{1},'real_shaded'); counts=real_counts; else; counts=gaussian_counts; end
            amplitudes = [0 5 10 20 40];
            for a=1:5
                c=counts(a,:);
                localization = NaN; new_alarm = NaN;
                if a>1; localization = 100*c(3)/max(1,c(1)); end
                if a>1 && c(4)>0; new_alarm=100*c(5)/c(4); end
                injection_rows(end+1,:) = {device,label,kind{1},amplitudes(a), ... %#ok<AGROW>
                    c(1),100*c(2)/max(1,c(1)),localization,c(4),new_alarm};
            end
        end
    end
    fprintf('REPLAY_DONE %s train=%d validation=%d scale=%.3f\n', ...
        device,numel(train),numel(validation),model.global_scale);
end
report.summary = cell2table(summary_rows,'VariableNames',{'device','variant', ...
    'train_epochs','validation_epochs','available_epochs','alarmed_epochs', ...
    'real_alarm_pct','median_dof','median_statistic_threshold_ratio','train_global_sigma_scale'});
report.injection = cell2table(injection_rows,'VariableNames',{'device','variant', ...
    'data_kind','fault_m','trials','alarm_pct','correct_localization_and_alarm_pct', ...
    'previously_passing_trials','new_alarm_pct_previously_passing'});
report.groups = cell2table(group_rows,'VariableNames',{'device','group_key','train_count','sigma_scale'});
report.innovation = cell2table(audit_rows,'VariableNames',{'device','epoch','available', ...
    'status','correlation_rcond','statistic','threshold','max_conditional_score'});
report.shadow = cell2table(shadow_rows,'VariableNames',{'device','variant','snapshot_index', ...
    'fault_m','injected_row','accepted','candidate_row','correct_injected_row', ...
    'status','position_variance_ratio','post_statistic_ratio'});
report.output_dir=out; report.manifest_file=manifest_file;
writetable(report.summary,fullfile(out,'heldout_summary.csv'));
writetable(report.injection,fullfile(out,'fault_injection.csv'));
writetable(report.groups,fullfile(out,'scale_groups.csv'));
writetable(report.innovation,fullfile(out,'innovation_audit.csv'));
writetable(report.shadow,fullfile(out,'shadow_exclusion.csv'));
save(fullfile(out,'report.mat'),'report');
fid=fopen(fullfile(out,'interpretation.txt'),'w');
assert(fid>=0); finish=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,['Chronological split: first half calibration, second half validation, 60s guard gap.\n' ...
    'Real shaded alarms are NOT false alarms: no fault-free labels exist.\n' ...
    'Injected faults are single-epoch observation faults, not persistent faults.\n' ...
    'Matched Gaussian trials use real geometry and assumed covariance, not real errors.\n' ...
    'Each nonzero amplitude tests both signs on every observable row.\n' ...
    'Localization means largest conditional/standardized score identifies the injected row AND global test alarms.\n' ...
    'Group keys: 0=global; 10000+10*system+frequency; 20000+1000*system+100*frequency+10*elevationBin+cn0Bin.\n' ...
    'Systems follow internal PRN/100; elevation bins <30,30-60,>=60 deg; CN0 bins <30,30-40,>=40 dB-Hz.\n' ...
    'Cell scale requires >=100 observations and shrinks toward system-frequency parent (weight=n/(n+200)).\n' ...
    'Scale is median(abs standardized residual)/0.67449, lower bounded by 1.\n' ...
    'No PPP observation was removed. No positioning improvement is claimed.\n']);
disp(report.summary);
end

function f=compactFrame(s)
A=s.Adjust; n=numel(s.Epoch.sats); nf=s.settings.INPUT.proc_freqs;
assert(strcmpi(s.settings.PROC.method,'Code + Phase'),'Replay currently supports code+phase.');
rows=(1:2:2*n*nf)'; H=A.A(rows,1:A.NO_PARAM); Q=A.Q(rows,rows); y=A.omc(rows);
valid=isfinite(y) & any(H~=0,2) & isfinite(diag(Q)) & diag(Q)>0;
sat=repmat(s.Epoch.sats(:),nf,1); freq=repelem((1:nf)',n);
elev=repmat(s.elevation_deg(:),nf,1); cn0=s.cn0(:);
system=floor(sat/100);
elev_bin=1+(elev>=30)+(elev>=60); cn0_bin=1+(cn0>=30)+(cn0>=40);
fine=20000+1000*system+100*freq+10*elev_bin+cn0_bin;
fine(~isfinite(elev) | ~isfinite(cn0))=NaN;
f=struct('y',y(valid),'H',H(valid,:),'Q',Q(valid,valid), ...
    'keys',[10000+10*system(valid)+freq(valid),fine(valid)], ...
    'sat',sat(valid),'freq',freq(valid));
end

function model=fitScales(rows)
w=rows(:,3); good=isfinite(w); rows=rows(good,:); w=w(good);
assert(numel(w)>=100,'Insufficient training observations.');
model.global_scale=max(1,median(w)/0.674489750196082);
model.keys=0; model.scales=model.global_scale; model.counts=numel(w);
for level=1:2
    keys=unique(rows(:,level)); keys=keys(isfinite(keys));
    for key=keys'
        take=rows(:,level)==key; n=sum(take);
        if n<100; continue; end
        parent=model.global_scale;
        if level==2
            parent_key=rows(find(take,1),1);
            idx=find(model.keys==parent_key,1);
            if ~isempty(idx); parent=model.scales(idx); end
        end
        empirical=max(1,median(w(take))/0.674489750196082);
        blend=n/(n+200);
        model.keys(end+1,1)=key;
        model.scales(end+1,1)=exp(blend*log(empirical)+(1-blend)*log(parent));
        model.counts(end+1,1)=n;
    end
end
end

function scale=predictScales(model,keys)
scale=repmat(model.global_scale,size(keys,1),1);
for level=1:2
    [found,idx]=ismember(keys(:,level),model.keys);
    scale(found)=model.scales(idx(found));
end
end

function counts=injectTrials(Y,T,W,threshold)
% Vectorized paired injections on every estimable observation, both signs.
counts=zeros(5,5);
base_T=T*Y; base_w=W*Y;
pass=sum(base_T.^2,1)<=threshold;
counts(1,:)=[size(Y,2),sum(~pass),0,0,0];
observable=find(sum(W.^2,2)>0);
for a=1:4
    amplitudes=[5 10 20 40];
    for j=observable'
        for sign=[-1 1]
            delta=sign*amplitudes(a);
            alarm=sum((base_T+delta*T(:,j)).^2,1)>threshold;
            [~,candidate]=max(abs(base_w+delta*W(:,j)),[],1);
            counts(a+1,:)=counts(a+1,:)+[size(Y,2),sum(alarm), ...
                sum(alarm & candidate==j),sum(pass),sum(alarm & pass)];
        end
    end
end
end
