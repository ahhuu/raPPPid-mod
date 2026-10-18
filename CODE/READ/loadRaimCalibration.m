function model = loadRaimCalibration(file)
% Load data only, reject incomplete/invalid frozen scale models.
if isempty(file)||~isfile(file); error('RAIM:CalibrationFile','Select an existing calibration MAT file.'); end
data=load(file,'model');
if ~isfield(data,'model')||~isstruct(data.model); error('RAIM:CalibrationModel','Calibration MAT must contain a model structure.'); end
model=data.model;
required={'global_scale','keys','scales'};
if ~all(isfield(model,required))||~isscalar(model.global_scale)|| ...
        ~isfinite(model.global_scale)||model.global_scale<=0|| ...
        ~isnumeric(model.keys)||~isnumeric(model.scales)|| ...
        numel(model.keys)~=numel(model.scales)||any(~isfinite(model.keys(:)))|| ...
        any(~isfinite(model.scales(:))|model.scales(:)<=0)||numel(unique(model.keys))~=numel(model.keys)
    error('RAIM:CalibrationModel','Invalid frozen RAIM keys/scales/global_scale.');
end
end
