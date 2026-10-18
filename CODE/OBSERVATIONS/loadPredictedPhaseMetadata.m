function metadata = loadPredictedPhaseMetadata(settings, obs)
% Load accepted Doppler-predicted phase records and index by time/sat/signal.

metadata = struct('enabled', false, 'lookup', [], 'file', '', ...
    'accepted_records', 0, 'selected_records', 0);
p = settings.PROC.predicted_phase;
if ~p.enable
    return;
end
file = char(p.metadata_file);
if isempty(file) || ~isfile(file)
    error('PredictedPhase:MetadataMissing', ...
        'Prediction metadata CSV does not exist: %s', file);
end

opts = detectImportOptions(file, 'Delimiter', ',');
opts = setvartype(opts, {'time','sat_id','freq','source','status'}, 'string');
T = readtable(file, opts);
required = {'time','sat_id','freq','prediction_length','sigma_m','accepted'};
if ~all(ismember(required, T.Properties.VariableNames))
    error('PredictedPhase:MetadataColumns', ...
        'Prediction metadata lacks required columns: %s', strjoin(required, ', '));
end

accepted = T.accepted;
if iscell(accepted) || isstring(accepted) || ischar(accepted)
    accepted = strcmpi(string(accepted), 'true') | string(accepted) == "1";
else
    accepted = logical(accepted);
end
metadata.accepted_records = nnz(accepted);
take = accepted & isfinite(T.prediction_length) & isfinite(T.sigma_m);
T = T(take,:);

quality = loadQualityRms(p);

dt = datetime(T.time, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSSSS');
[week, sow] = calendarToGps(dt);
time_ms = int64(round((double(week)*604800 + double(sow))*1000));

% Reject a sidecar from another session instead of silently mapping nothing.
if isfield(obs,'startdate') && numel(obs.startdate)>=6 && ~isempty(time_ms)
    start_time=datetime(obs.startdate);
    if isfield(obs,'enddate') && numel(obs.enddate)>=6 && all(isfinite(obs.enddate)) && obs.enddate(1)>1980
        end_time=datetime(obs.enddate);
    elseif isfield(obs,'newdataepoch') && isfield(obs,'interval')
        end_time=start_time+seconds(max(0,numel(obs.newdataepoch)-1)*obs.interval);
    else
        end_time=start_time+days(1);
    end
    if ~any(dt>=start_time-milliseconds(p.time_tolerance_ms) & dt<=end_time+milliseconds(p.time_tolerance_ms))
        error('PredictedPhase:SessionMismatch','Prediction metadata does not overlap the observation session.');
    end
end

lookup = containers.Map('KeyType','char','ValueType','any');
for i = 1:height(T)
    sat = rinexSatelliteNumber(T.sat_id(i));
    key = predictionKey(time_ms(i), sat, T.freq(i));
    allowed = signalAllowed(T.sat_id(i), T.freq(i), p.allowed_signals);
    [quality_ok, quality_rms] = qualityForRecord(quality, T.sat_id(i), ...
        T.freq(i), T.prediction_length(i), p);
    eligible = T.prediction_length(i) <= p.max_prediction_length && allowed && quality_ok;
    sigma = max(p.sigma_floor_m, p.sigma_scale*double(T.sigma_m(i)));
    if isfinite(quality_rms)
        sigma = max(sigma, p.quality_sigma_scale*quality_rms);
    end
    value = [double(T.prediction_length(i)), ...
        sigma, double(eligible)];
    lookup(key) = value;
end
metadata.enabled = true;
metadata.lookup = lookup;
metadata.file = file;
metadata.selected_records = sum(cellfun(@(v) v(3) ~= 0, values(lookup)));
metadata.time_tolerance_ms = max(0, round(p.time_tolerance_ms));
metadata.signal_labels = selectedPhaseLabels(obs);
end

function quality = loadQualityRms(p)
quality = containers.Map('KeyType','char','ValueType','any');
file = char(p.quality_rms_file);
if isempty(file) || ~isfile(file)
    return;
end
opts = detectImportOptions(file, 'Delimiter', ',');
opts = setvartype(opts, {'satellite','frequency'}, 'string');
Q = readtable(file, opts);
required = {'satellite','frequency','prediction_length','sample_count','rms_m'};
if ~all(ismember(required, Q.Properties.VariableNames))
    error('PredictedPhase:QualityColumns', ...
        'Prediction quality CSV lacks required columns: %s', strjoin(required, ', '));
end
for i = 1:height(Q)
    key = qualityKey(Q.satellite(i), Q.frequency(i), Q.prediction_length(i));
    quality(key) = [double(Q.rms_m(i)), double(Q.sample_count(i))];
end
end

function [ok, rms_m] = qualityForRecord(quality, sat, freq, prediction_length, p)
key = qualityKey(sat, freq, prediction_length);
if ~isKey(quality,key)
    rms_m = NaN;
    ok = ~p.reject_if_quality_missing;
    return;
end
value = quality(key);
rms_m = value(1);
ok = isfinite(rms_m) && rms_m <= p.quality_max_rms_m && value(2) >= p.quality_min_samples;
end

function allowed = signalAllowed(sat, freq, allowed_signals)
if isempty(allowed_signals)
    allowed = true;
    return;
end
sat = char(sat); freq = upper(char(freq));
key = sprintf('%s:%s', upper(sat(1)), freq);
allowed = any(strcmpi(key, string(allowed_signals)));
end

function key = qualityKey(sat, freq, prediction_length)
key = sprintf('%s|%s|%d', upper(char(sat)), upper(char(freq)), round(prediction_length));
end

function [week, sow] = calendarToGps(dt)
delta = dt - datetime(1980,1,6,0,0,0);
week = floor(days(delta)/7);
sow = seconds(delta - days(week*7));
end

function sat = rinexSatelliteNumber(id)
id = char(id);
prn = str2double(id(2:end));
switch upper(id(1))
    case 'G'; offset = 0;
    case 'R'; offset = 100;
    case 'E'; offset = 200;
    case 'C'; offset = 300;
    case 'J'; offset = 400;
    otherwise; error('PredictedPhase:SatelliteId', 'Unsupported satellite id: %s', id);
end
sat = offset + prn;
end

function labels = selectedPhaseLabels(obs)
systems = {'GPS','GLO','GAL','BDS','QZSS'};
labels = strings(5,3);
for s = 1:5
    for f = 1:3
        field = sprintf('L%d', f);
        if isfield(obs.(systems{s}), field) && ~isempty(obs.(systems{s}).(field))
            labels(s,f) = string(obs.(systems{s}).(field));
        end
    end
end
end

function key = predictionKey(time_ms, sat, signal)
signal = upper(char(signal));
% raPPPid normalizes legacy BDS-2 L2I/Q/X labels to L1I/Q/X.
if sat >= 300 && sat < 400 && numel(signal) == 3 && signal(2) == '2' && any(signal(3) == 'IQX')
    signal(2) = '1';
end
key = sprintf('%d|%d|%s', time_ms, sat, signal);
end
