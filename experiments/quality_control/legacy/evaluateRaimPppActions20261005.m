function metrics = evaluateRaimPppActions20261005(manifest_file)
% Fixed, truth-independent protocol. Compare all input and held-out epochs.
S=load(manifest_file,'runs'); runs=S.runs;
root=fileparts(manifest_file); rows={}; windows={}; audit={}; input_audit={}; series=struct;
coords=readlines('../DATA/COORDS/Coords.txt');
devices={'K80','X6','ACE5'}; stations={'H111','X111','A111'}; expected=[3600 3600 2272];
variants={'baseline','exclude_code','downweight_code'};
for k=1:3
    device=devices{k}; line=coords(startsWith(strtrim(coords),stations{k}));
    assert(numel(line)==1); fields=regexp(char(strtrim(line)),'\s+','split'); truth=str2double(fields(3:5));
    assert(all(isfinite(truth)) && isequal(size(truth),[1 3]));
    [lat,lon]=xyz2ell(truth); R=[-sin(lat)*cos(lon),-sin(lat)*sin(lon),cos(lat);-sin(lon),cos(lon),0;cos(lat)*cos(lon),cos(lat)*sin(lon),sin(lat)];
    D=cell(1,3); valid=false(expected(k),3); errors=cell(1,3);
    for j=1:3
        idx=find(strcmp(runs.device,device)&strcmp(runs.variant,variants{j})); assert(numel(idx)==1);
        L=load(fullfile(runs.output_dir(idx),'data4plot.mat'),'storeData'); D{j}=L.storeData;
        t=D{j}.gpstime(:); p=D{j}.param(:,1:3); assert(numel(t)==expected(k));
        if j==1; times=t; start=runs.validation_start_sow(idx); else; assert(isequal(t,times)); end
        valid(:,j)=logical(D{j}.float(:)) & all(isfinite(p),2) & all(p~=0,2);
        errors{j}=(p-truth)*R';
        if j>1
            pre=times<start; assert(isequaln(p(pre,:),D{1}.param(pre,1:3)),'Pre-validation trajectory changed');
            assert(~any(D{j}.raim_action_code(pre)));
        end
        saved=load(fullfile(runs.output_dir(idx),'settings.mat'),'settings');
        if j==1
            baseline_settings=saved.settings;
        else
            for section={'INPUT','ADJ','IONO','TROPO','BIASES'}
                key=section{1};
                if isfield(baseline_settings,key)
                    assert(configEqual(baseline_settings.(key),saved.settings.(key)), ...
                        'Configuration differs outside RAIM: %s',key);
                end
            end
        end
        acted=D{j}.raim_action_code(:)>0;
        assert(all(D{j}.raim_action_post_ratio(acted)<=1+1e-10));
        assert(all(D{j}.raim_action_geometry_ratio(acted)<=2+1e-10));
        assert(all(isfinite(D{j}.raim_action_satellite(acted))));
        if j==1
            raw=readlines(saved.settings.INPUT.file_obs); headers=raw(startsWith(raw,'>'));
            dates=zeros(numel(headers),6);
            for ii=1:numel(headers)
                parts=sscanf(extractAfter(headers(ii),1),'%f'); dates(ii,:)=parts(1:6)';
            end
            raw_sow=mod((datenum(dates)-datenum(1980,1,6))*86400,604800);
            assert(numel(raw_sow)==numel(times),'Raw input epoch count mismatch');
            difference=max(abs(raw_sow-times));
            assert(difference<0.01,'Raw RINEX/result times differ by >=10 ms');
            input_audit(end+1,:)={device,numel(raw_sow),difference,nnz(diff(raw_sow)>1.5)}; %#ok<AGROW>
        end
        audit(end+1,:)={device,variants{j},stations{k},truth(1),truth(2),truth(3),char(saved.settings.INPUT.file_obs),char(runs.source_settings(idx)),start}; %#ok<AGROW>
    end
    common=all(valid,2); held=times>=start;
    for period={'all_input','heldout'}
        mask=true(size(times)); if strcmp(period{1},'heldout'); mask=held; end
        for support={'own_valid','common_valid'}
            for j=1:3
                use=mask & valid(:,j); if strcmp(support{1},'common_valid'); use=mask & common; end
                e=errors{j}; h=hypot(e(:,1),e(:,2)); d=sqrt(sum(e.^2,2));
                reset=false(size(times));
                if isfield(D{j},'float_reset_epochs')
                    ix=D{j}.float_reset_epochs; ix=ix(ix>=1 & ix<=numel(times)); reset(ix)=true;
                elseif isfield(D{j},'dt_last_reset'); reset=D{j}.dt_last_reset(:)==0; end
                rows(end+1,:)={device,variants{j},period{1},support{1},nnz(mask),nnz(use),100*nnz(mask & valid(:,j))/nnz(mask), ...
                    rms(e(use,1)),rms(e(use,2)),rms(e(use,3)),rms(h(use)),rms(d(use)), ...
                    prctile(h(use),50),prctile(h(use),95),prctile(d(use),50),prctile(d(use),95), ...
                    nnz(mask & D{j}.raim_action_code(:)>0),nnz(mask & reset), ...
                    100*nnz(mask & valid(:,j) & h<5 & d<10)/nnz(mask), ...
                    convergenceSeconds(times,mask & valid(:,j) & h<5 & d<10,reset,mask)}; %#ok<AGROW>
            end
        end
    end
    for a=start:300:max(times)
        mask=held & times>=a & times<a+300 & common;
        for j=2:3
            b=errors{1}; e=errors{j};
            windows(end+1,:)={device,variants{j},a,min(a+300,max(times)),nnz(mask), ...
                rms(sqrt(sum(b(mask,:).^2,2))),rms(sqrt(sum(e(mask,:).^2,2)))}; %#ok<AGROW>
        end
    end
    series.(device)=struct('time',times,'validation_start',start,'valid',valid,'neu',{errors},'truth',truth);
    f=figure('Visible','off','Position',[100 100 1200 800]);
    for component=1:3
        subplot(3,1,component); hold on;
        for j=1:3
            y=errors{j}(:,component); y(~valid(:,j))=NaN; plot((times-times(1))/60,y);
        end
        xline((start-times(1))/60,'--');
        labels={'North (m)','East (m)','Up (m)'}; ylabel(labels{component}); grid on;
    end
    xlabel('Minutes from first input epoch'); legend(variants,'Interpreter','none');
    sgtitle([device ' PPP errors; dashed: held-out start']);
    exportgraphics(f,fullfile(root,[device '_NEU.png'])); close(f);
end
metrics=cell2table(rows,'VariableNames',{'device','variant','period','support','input_epochs','evaluated_epochs','valid_pct','rmse_N','rmse_E','rmse_U','rmse_H','rmse_3D','p50_H','p95_H','p50_3D','p95_3D','actions','reset_epochs','input_success_H5_D10_pct','first_60s_success_onset_s'});
degradation=cell2table(windows,'VariableNames',{'device','variant','start_sow','end_sow','common_epochs','baseline_rmse3D','action_rmse3D'});
degradation.delta_rmse3D=degradation.action_rmse3D-degradation.baseline_rmse3D;
provenance=cell2table(audit,'VariableNames',{'device','variant','station','truth_X','truth_Y','truth_Z','input_obs','source_settings','validation_start_sow'});
input_alignment=cell2table(input_audit,'VariableNames',{'device','raw_input_epochs','max_time_difference_s','raw_gaps_gt1p5s'});
writetable(input_alignment,fullfile(root,'input_alignment.csv'));
writetable(metrics,fullfile(root,'precision_metrics.csv')); writetable(degradation,fullfile(root,'degradation_windows.csv')); writetable(provenance,fullfile(root,'provenance.csv'));
save(fullfile(root,'precision_results.mat'),'metrics','degradation','provenance','series','runs','input_alignment');
disp(metrics(strcmp(metrics.period,'heldout')&strcmp(metrics.support,'common_valid'),:));
end

function yes=configEqual(a,b)
% MAT-reloaded anonymous handles differ in identity; compare captured data too.
if isa(a,'function_handle') && isa(b,'function_handle')
    yes=configEqual(functions(a),functions(b));
elseif isstruct(a) && isstruct(b)
    yes=isequal(size(a),size(b)) && isequal(fieldnames(a),fieldnames(b));
    if ~yes; return; end
    names=fieldnames(a);
    for i=1:numel(a)
        for j=1:numel(names)
            if ~configEqual(a(i).(names{j}),b(i).(names{j})); yes=false; return; end
        end
    end
elseif iscell(a) && iscell(b)
    yes=isequal(size(a),size(b));
    if ~yes; return; end
    for i=1:numel(a)
        if ~configEqual(a{i},b{i}); yes=false; return; end
    end
else
    yes=isequaln(a,b);
end
end

function value=convergenceSeconds(t,good,reset,period)
% First 60 consecutive one-second input epochs satisfying H<5 and 3D<10,
% without a filter reset inside that interval. NaN means not observed.
value=NaN; begin=0; origin=t(find(period,1));
for i=1:numel(t)
    if ~good(i); begin=0; continue; end
    if begin==0 || reset(i) || (i>1 && t(i)-t(i-1)>1.5); begin=i; end
    if i-begin+1>=60 && t(i)-t(begin)>=59
        value=t(begin)-origin; return;
    end
end
end
