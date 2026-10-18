function errors = validateQualityControlSettings(settings, check_files)
% Noninteractive validation shared by GUI and direct PPP entry.
if nargin<2; check_files=true; end
errors={}; s=applyQualityControlDefaults(settings); rows=qualityControlSchema();
retired={'OTHER.mp_soft','PROC.omc_soft_code','PROC.omc_soft_phase','ADJ.smartphone_stochastic.enable'};
for k=1:numel(retired)
    [~,v,found]=qualityControlField(settings,retired{k});
    if found && any(v(:)); errors{end+1}=['Retired experiment enabled: ' retired{k} '. Use the archived experiment source or disable it.']; end
end
for k=1:size(rows,1)
    [~,v]=qualityControlField(s,rows{k,2}); type=rows{k,5};
    if iscell(type)
        if ~ischar(v) || ~any(strcmp(v,type)); add([rows{k,3} ': invalid selection.']); end
    elseif strcmp(type,'bool')
        if ~(islogical(v)||isnumeric(v)) || ~isscalar(v) || ~ismember(v,[0 1]); add([rows{k,3} ': use true/false.']); end
    elseif strcmp(type,'number')
        if ~isnumeric(v)||~isscalar(v)||~isreal(v); add([rows{k,3} ': expected one real number.']); end
    elseif strcmp(type,'file')
        if ~(ischar(v)&&isrow(v)) && ~isempty(v); add([rows{k,3} ': expected a file path.']); end
    end
end
if ~isempty(errors); return; end
c=s.PROC.cold_start; p=s.PROC.predicted_phase; r=s.PROC.raim; d=s.OTHER.CS;
positive(d.D_mad_factor,'Doppler MAD multiplier');
mask(d.D_freq_enable,[1 3],'Doppler frequency mask');
mask(d.D_system_freq_enable,[5 3],'Doppler system/frequency mask');
positive(d.TDCP_z_factor,'TDCP MAD multiplier');
integer(d.TDCP_min_sats,6,Inf,'TDCP minimum satellites');
integer(d.TDCP_max_reject,0,Inf,'TDCP maximum rejections');
if c.enable
    integer(c.window_epochs,1,Inf,'Cold-start window'); integer(c.min_samples,1,c.window_epochs,'Cold-start samples');
    positive(c.huber_c,'Cold-start Huber multiplier'); positive(c.scale_floor_m,'Cold-start scale');
    if ~isfinite(c.weight_floor)||c.weight_floor<=0||c.weight_floor>1; add('Cold-start weight must be in (0,1].'); end
    if ~isfield(s.PROC,'method') || ~strcmpi(s.PROC.method,'Code + Phase') || ...
            ~(s.PROC.AdjustPhase2Code || s.PROC.bool_rec_clk_jump)
        add('Cold start requires Code + Phase and phase-to-code adjustment or receiver clock-jump handling.');
    end
end
if p.enable
    if p.max_prediction_length~=Inf; integer(p.max_prediction_length,1,Inf,'Prediction length'); end
    positive(p.sigma_scale,'Prediction sigma multiplier'); positive(p.sigma_floor_m,'Prediction sigma floor');
    positive(p.quality_sigma_scale,'Quality sigma multiplier'); positive(p.quality_max_rms_m,'Quality RMS limit');
    integer(p.quality_min_samples,0,Inf,'Quality sample count'); integer(p.time_tolerance_ms,0,1000,'Time tolerance');
    if ~iscellstr(p.allowed_signals); add('Allowed signals must be a cell array of strings.'); end
    if check_files
        csvfile(p.metadata_file,{'time','sat_id','freq','prediction_length','sigma_m','accepted'},'Prediction metadata');
        if p.reject_if_quality_missing || ~isempty(p.quality_rms_file)
            csvfile(p.quality_rms_file,{'satellite','frequency','prediction_length','sample_count','rms_m'},'Prediction quality');
        end
    end
end
if r.enable
    if ~isfinite(r.pfa_global)||r.pfa_global<=0||r.pfa_global>=1; add('RAIM PFA must be in (0,1).'); end
    integer(r.min_redundancy,1,Inf,'RAIM redundancy'); integer(r.capture_stride,0,Inf,'RAIM capture interval');
    if ~strcmp(r.experiment_action,'none')
        if ~strcmp(s.PROC.method,'Code + Phase') || contains(s.IONO.model,'decoupled','IgnoreCase',true)
            add('RAIM actions require supported non-decoupled Code + Phase processing.');
        end
        if ~strcmp(r.test_model,'wls_residual'); add('RAIM actions use the calibrated WLS residual model.'); end
        integer(r.validation_gps_week,0,Inf,'RAIM action GPS week');
        integer(r.validation_start_sow,0,604799.999999,'RAIM action start SOW',false);
        if ~isfinite(r.downweight_variance_factor)||r.downweight_variance_factor<1; add('RAIM variance multiplier must be >=1.'); end
        if check_files
            try; loadRaimCalibration(r.calibration_file);
            catch ex; add(ex.message); end
        end
    end
end
if check_files && isfield(s.INPUT,'bool_batch') && s.INPUT.bool_batch && ...
        (p.enable || (r.enable && ~strcmp(r.experiment_action,'none'))) && ...
        (~isfield(s.PROC,'quality_control_single_input') || ~s.PROC.quality_control_single_input)
    add('Prediction/RAIM action files must be bound to one input. Use single-file processing; batch scripts must explicitly set PROC.quality_control_single_input after binding each row.');
end
    function add(message); errors{end+1}=message; end
    function positive(v,name)
        if isnan(v)||v<=0; add([name ' must be positive.']); end
    end
    function integer(v,lo,hi,name,whole)
        if nargin<5; whole=true; end
        if ~isfinite(v)||v<lo||v>hi||(whole && v~=floor(v)); add([name ' is out of range.']); end
    end
    function mask(v,shape,name)
        if ~isequal(size(v),shape)||~all(ismember(v(:),[0 1])); add([name ' has invalid shape or values.']); end
    end
    function csvfile(file,columns,name)
        if ~isfile(file); add([name ' file does not exist.']); return; end
        try
            opts=detectImportOptions(file,'Delimiter',',');
            if ~all(ismember(columns,opts.VariableNames)); add([name ' is missing required CSV columns.']); end
        catch ex; add([name ': ' ex.message]); end
    end
end
