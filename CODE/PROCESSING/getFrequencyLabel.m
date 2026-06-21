function freq_label = getFrequencyLabel(prn, freq_idx, settings)
% Get frequency label for a satellite and frequency index from settings.
% Example return values: 'C1C', 'C5Q', 'C2I', 'OFF', 'UNKNOWN'.
%
% INPUT:
%   prn       integer, satellite PRN code in raPPPid encoding
%   freq_idx  integer, frequency index (1, 2, 3)
%   settings  struct, processing settings
% OUTPUT:
%   freq_label string
%
% This function belongs to raPPPidV5.0, adapted from raPPPid.
% *************************************************************************

if prn <= 99
    freq_settings = settings.INPUT.gps_freq;
elseif prn >= 101 && prn <= 199
    freq_settings = settings.INPUT.glo_freq;
elseif prn >= 201 && prn <= 299
    freq_settings = settings.INPUT.gal_freq;
elseif prn >= 301 && prn <= 399
    freq_settings = settings.INPUT.bds_freq;
elseif prn >= 401 && prn <= 410
    freq_settings = settings.INPUT.qzss_freq;
else
    freq_label = 'UNKNOWN';
    return;
end

if freq_idx > length(freq_settings) || strcmpi(freq_settings{freq_idx}, 'OFF')
    freq_label = 'OFF';
    return;
end

freq_code = freq_settings{freq_idx};
if ~isempty(freq_code)
    freq_label = freq_code;
else
    freq_label = 'UNKNOWN';
end
end
