function comparison = verifyRaimMonitorCompatibility20261005(manifest_file)
%VERIFYRAIMMONITORCOMPATIBILITY20261005 Matched short PPP on/off comparison.
% This compares current code and identical settings in a single MATLAB
% session, independently of historical processing changes.
M = load(manifest_file,'manifest'); m = M.manifest;
rows = {};
for k=1:height(m)
    device=char(m.device(k)); source=char(m.output_dir(k));
    S=load(fullfile(source,'settings.mat'),'settings'); base=S.settings;
    base.PROC.epochs=[1 60]; base.PROC.timeFrame=[1 60];
    base.PROC.timeFrameFrom='1'; base.PROC.timeFrameTo='60';
    base.PROC.timeSpan_format_epochs=true; base.PROC.timeSpan_format_time=false;
    base.PROC.timeSpan_format_SOD=false; base.PROC.timeSpan_format_HOD=false;
    base.PROC.raim.capture_stride=0;
    results=cell(2,1);
    for enabled=0:1
        s=base; s.PROC.raim.enable=logical(enabled);
        s.PROC.name=sprintf('PPP_RAIM_AB_20261005/%s_%d',device,enabled);
        evalc('out=PPP_main(s);');
        R=load(fullfile(out.PROC.output_dir,'data4plot.mat'),'storeData');
        results{enabled+1}=R.storeData;
    end
    off=results{1}; on=results{2};
    assert(isequaln(off.gpstime,on.gpstime) && isequaln(off.float,on.float));
    assert(isequaln(off.param,on.param),'RAIM changed the PPP parameter solution.');
    assert(isequaln(off.param_var,on.param_var),'RAIM changed the formal covariance.');
    rows(end+1,:)={device,numel(off.gpstime),true, ... %#ok<AGROW>
        max(abs(off.param(:,1:3)-on.param(:,1:3)),[],'all')};
    fprintf('RAIM_AB_PASS %s epochs=%d exact_parameter_equality=1\n',device,numel(off.gpstime));
end
comparison=cell2table(rows,'VariableNames',{'device','epochs','exact_parameter_equality','max_xyz_change_m'});
folder=fileparts(manifest_file);
writetable(comparison,fullfile(folder,'monitor_compatibility.csv'));
save(fullfile(folder,'monitor_compatibility.mat'),'comparison');
end
