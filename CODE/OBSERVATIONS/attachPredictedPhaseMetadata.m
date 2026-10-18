function Epoch = attachPredictedPhaseMetadata(Epoch, metadata, settings, obs)
% Attach prediction flag, prediction length and sigma to current observations.

n = numel(Epoch.sats);
nf = settings.INPUT.proc_freqs;
Epoch.phase_predicted = false(n,nf);
Epoch.phase_prediction_length = zeros(n,nf);
Epoch.phase_prediction_sigma_m = NaN(n,nf);
Epoch.phase_prediction_rejected = false(n,nf);
if ~metadata.enabled || n == 0
    return;
end

time_ms = int64(round((double(Epoch.gps_week)*604800 + double(Epoch.gps_time))*1000));
for i = 1:n
    system = satelliteSystemRow(Epoch.sats(i));
    for f = 1:nf
        signal = metadata.signal_labels(system,f);
        if strlength(signal) == 0
            continue;
        end
        value = [];
        for dt = 0:metadata.time_tolerance_ms
            offsets = unique([dt, -dt]);
            for k = 1:numel(offsets)
                key = predictionKey(time_ms+offsets(k), Epoch.sats(i), signal);
                if isKey(metadata.lookup, key)
                    value = metadata.lookup(key);
                    break;
                end
            end
            if ~isempty(value); break; end
        end
        if ~isempty(value)
            if value(3) ~= 0
                Epoch.phase_predicted(i,f) = true;
                Epoch.phase_prediction_length(i,f) = value(1);
                Epoch.phase_prediction_sigma_m(i,f) = value(2);
            else
                % Present in rewritten RINEX but outside this length gate.
                Epoch.phase_prediction_rejected(i,f) = true;
                phase_field = sprintf('L%d',f);
                Epoch.(phase_field)(i) = NaN;
                col = obs.use_column{system,f};
                if ~isempty(col) && col > 0
                    Epoch.obs(i,col) = NaN;
                end
            end
        end
    end
end
end

function key = predictionKey(time_ms, sat, signal)
signal = upper(char(signal));
if sat >= 300 && sat < 400 && numel(signal) == 3 && signal(2) == '2' && any(signal(3) == 'IQX')
    signal(2) = '1';
end
key = sprintf('%d|%d|%s', time_ms, sat, signal);
end

function row = satelliteSystemRow(sat)
if sat < 100; row = 1;
elseif sat < 200; row = 2;
elseif sat < 300; row = 3;
elseif sat < 400; row = 4;
else; row = 5;
end
end
