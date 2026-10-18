function runs = runRaimPppActions20261005(evidence_file, devices, epoch_limit)
%RUNRAIMPPPACTIONS20261005 Preregistered baseline/exclude/downweight PPP runs.
% Frozen model uses first-half observations only; actions begin in held-out
% second half. Full-run output includes the unchanged calibration period.
if nargin<2; devices={'K80','X6','ACE5'}; end
if nargin<3; epoch_limit=Inf; end
S=load(evidence_file,'report'); report=S.report;
M=load(report.manifest_file,'manifest'); sources=M.manifest;
root=fullfile(Path.RESULTS,'PPP_RAIM_ACTIONS_20261005');
if isfinite(epoch_limit); root=[root '_smoke']; end
if ~isfolder(root); mkdir(root); end
runs=table('Size',[0 7],'VariableTypes',{'string','string','string','string','string','double','double'},'VariableNames',{'device','variant','output_dir', ...
    'source_settings','calibration_file','validation_start_sow','epochs'});
manifest_file=fullfile(root,'action_manifest.mat');
if isfile(manifest_file)
    previous=load(manifest_file,'runs'); runs=previous.runs;
end
for k=1:height(sources)
    device=char(sources.device(k));
    if ~any(strcmp(device,devices)); continue; end
    source_settings=fullfile(char(sources.output_dir(k)),'settings.mat');
    saved=load(source_settings,'settings'); base=saved.settings;
    calibration_file=fullfile(fileparts(evidence_file),[device '_calibration.mat']);
    C=load(calibration_file,'model','times','train','validation');
    validation_start=min(C.times(C.validation));
    assert(max(C.times(C.train))<validation_start-30);
    for variant={'baseline','exclude_code','downweight_code'}
        name=variant{1};
        existing=strcmp(runs.device,device) & strcmp(runs.variant,name);
        if any(existing)
            for index=find(existing)'
                assert(isfile(fullfile(char(runs.output_dir(index)),'data4plot.mat')));
            end
            fprintf('ACTION_REUSE %s %s\n',device,name); continue;
        end
        s=base; s.INPUT.bool_batch=true; s.INPUT.bool_parfor=true;
        [~,group]=fileparts(root);
        s.PROC.name=sprintf('%s/%s_%s',group,device,name);
        s.PROC.raim.enable=true; s.PROC.raim.capture_stride=0;
        s.PROC.raim.test_model='wls_residual';
        s.PROC.raim.experiment_action='none';
        if ~strcmp(name,'baseline'); s.PROC.raim.experiment_action=name; end
        s.PROC.raim.calibration=C.model;
        s.PROC.raim.calibration_file=calibration_file;
        s.PROC.raim.validation_start_sow=validation_start;
        s.PROC.raim.downweight_variance_factor=25;
        if isfinite(epoch_limit)
            s.PROC.epochs=[1 epoch_limit]; s.PROC.timeFrame=[1 epoch_limit];
            s.PROC.timeFrameFrom='1'; s.PROC.timeFrameTo=num2str(epoch_limit);
            s.PROC.timeSpan_format_epochs=true; s.PROC.timeSpan_format_time=false;
            s.PROC.timeSpan_format_SOD=false; s.PROC.timeSpan_format_HOD=false;
            % Smoke checks exercise the action, but are never precision evidence.
            s.PROC.raim.validation_start_sow=-Inf;
        end
        fprintf('ACTION_START %s %s\n',device,name);
        logtext=evalc('out=PPP_main(s);');
        fid=fopen(fullfile(out.PROC.output_dir,'processing_console.txt'),'w');
        assert(fid>=0); fwrite(fid,logtext); fclose(fid);
        D=load(fullfile(out.PROC.output_dir,'data4plot.mat'),'storeData');
        assert(isfield(D.storeData,'raim_action_code'));
        if strcmp(name,'baseline'); assert(~any(D.storeData.raim_action_code)); end
        if isfinite(epoch_limit); start=-Inf; else; start=validation_start; end
        assert(~any(D.storeData.raim_action_code(D.storeData.gpstime<start)));
        runs(end+1,:)={device,name,char(out.PROC.output_dir),source_settings, ...
            calibration_file,start,numel(D.storeData.gpstime)};
        save(manifest_file,'runs','evidence_file');
        writetable(runs,fullfile(root,'action_manifest.csv'));
        fprintf('ACTION_DONE %s %s epochs=%d modified=%d\n',device,name, ...
            numel(D.storeData.gpstime),nnz(D.storeData.raim_action_code));
    end
end
end
