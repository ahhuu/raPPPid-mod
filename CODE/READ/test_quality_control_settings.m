function test_quality_control_settings()
s=applyQualityControlDefaults(struct());
assert(~s.PROC.cold_start.enable && ~s.PROC.predicted_phase.enable && ~s.PROC.raim.enable);
s.PROC.cold_start.window_epochs=17;
s.PROC.raim.experiment_action='downweight_code';
s.PROC.raim.calibration=struct('must_not_inherit',true);
s.PROC.omc_soft_code=true;
t=copyQualityControlSettings(struct(),s);
assert(t.PROC.cold_start.window_epochs==17);
assert(strcmp(t.PROC.raim.experiment_action,'downweight_code'));
assert(~isfield(t.PROC.raim,'calibration') && ~isfield(t.PROC,'omc_soft_code'));
t=applyQualityControlDefaults(struct());
assert(isempty(validateQualityControlSettings(t,false)));
t.OTHER.CS.D_system_freq_enable=ones(4,3);
assert(~isempty(validateQualityControlSettings(t,false)));
t=applyQualityControlDefaults(struct()); t.PROC.cold_start.enable=true;
t.PROC.method='Code + Phase'; t.PROC.AdjustPhase2Code=true; t.PROC.bool_rec_clk_jump=false;
t.PROC.cold_start.min_samples=11;
assert(~isempty(validateQualityControlSettings(t,false)));
t.PROC.cold_start.min_samples=3;
assert(isempty(validateQualityControlSettings(t,false)));
t.PROC.predicted_phase.enable=true; t.INPUT.bool_batch=false;
assert(~isempty(validateQualityControlSettings(t,true)));
file=[tempname '.mat']; cleanup=onCleanup(@() delete(file)); %#ok<NASGU>
model=struct('global_scale',1,'keys',[1;2],'scales',[1;2]); save(file,'model');
assert(isequal(loadRaimCalibration(file),model));
model.scales(1)=-1; save(file,'model');
failed=false; try; loadRaimCalibration(file); catch; failed=true; end
assert(failed);
source=struct('exclude_freq',true(2,3,2),'cs_found_freq',false(2,3,2), ...
    'exclude',ones(2,3),'cs_found',zeros(2,3),'param',ones(2,4),'raim_available',true(2,1));
small=compactQualityDiagnostics(source);
assert(~isfield(small,'exclude_freq') && ~isfield(small,'cs_found_freq'));
assert(isequal(small.param,source.param) && isequal(small.exclude,source.exclude));
t=applyQualityControlDefaults(struct()); t.PROC.omc_soft_code=true;
assert(~isempty(validateQualityControlSettings(t,false)));
fprintf('test_quality_control_settings: PASS\n');
end
