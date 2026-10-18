function results = runQualityControlExperiment(settings_file, name, mode)
% Portable runner: explicit settings template, output prefix and experiment.
% Run from WORK. All observations/products/sidecars are taken from settings.
% mode: 'single', 'cold_start_ablation', 'raim_actions'. Never edits inputs.
if nargin<3; mode='single'; end
assert(isfile(settings_file),'Settings MAT does not exist.');
assert(~isempty(regexp(name,'^[A-Za-z0-9_-]+$','once')),'Use a simple output name.');
data=load(settings_file,'settings'); base=applyQualityControlDefaults(data.settings);
switch mode
    case 'single'; labels={'single'};
    case 'cold_start_ablation'; labels={'R0_C0','R0_C1','R1_C0','R1_C1'};
    case 'raim_actions'; labels={'none','exclude_code','downweight_code'};
    otherwise; error('Unknown experiment mode.');
end
global STOP_CALC; STOP_CALC=0;
results=cell(numel(labels),1);
for k=1:numel(labels)
    s=base; s.INPUT.bool_batch=true; s.INPUT.bool_parfor=true;
    % Each invocation binds exactly one explicitly supplied settings file.
    s.PROC.quality_control_single_input=true;
    s.PROC.name=[name '/' labels{k}];
    if strcmp(mode,'cold_start_ablation')
        s.PROC.reset_float=labels{k}(2)=='1'; s.PROC.reset_fixed=false;
        s.PROC.cold_start.enable=labels{k}(5)=='1';
        s.PROC.cold_start.robust_code=s.PROC.cold_start.enable;
    elseif strcmp(mode,'raim_actions')
        s.PROC.raim.enable=true; s.PROC.raim.experiment_action=labels{k};
    end
    results{k}=PPP_main(s);
end
end
