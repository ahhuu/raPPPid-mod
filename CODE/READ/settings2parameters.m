function [parameters] = settings2parameters(settings)

% settings2parameters is used to convert from settings to parameters
% struct. The idea is, that "parameters" contains all observation-file/
% session-independent (global) settings, while "settings" contains 
% observation-file/session-dependent settings as well.
% 
% INPUT:    
%   settings        struct, settings for processing with PPP_main.m 
% OUTPUT:   
%   parameters     	struct, contains parts of settings struct
%
%  
% Revision:
% 	2023/08/04, MFG: improved export of variables
% 
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************



% define the equivalent variables
parameters.ORBCLK = settings.ORBCLK;
parameters.TROPO  = settings.TROPO;
parameters.IONO   = settings.IONO;
parameters.BIASES = settings.BIASES;
parameters.OTHER  = settings.OTHER;
parameters.AMBFIX = settings.AMBFIX;
parameters.ADJ    = settings.ADJ;
parameters.PROC   = settings.PROC;

% delete variables which are observation-file-specific
parameters.PROC = rmfield(parameters.PROC, 'name');
parameters.PROC = rmfield(parameters.PROC, 'timeFrameFrom');
parameters.PROC = rmfield(parameters.PROC, 'timeFrameTo');
parameters.PROC = rmfield(parameters.PROC, 'timeFrame');
parameters.PROC = rmfield(parameters.PROC, 'timeSpan_format_epochs');
parameters.PROC = rmfield(parameters.PROC, 'timeSpan_format_HOD');
parameters.PROC = rmfield(parameters.PROC, 'timeSpan_format_SOD');
parameters.PROC = rmfield(parameters.PROC, 'reset_float');
parameters.PROC = rmfield(parameters.PROC, 'reset_fixed');
parameters.PROC = rmfield(parameters.PROC, 'reset_after');
parameters.PROC = rmfield(parameters.PROC, 'reset_bool_epoch');
parameters.PROC = rmfield(parameters.PROC, 'reset_bool_min');
parameters.PROC = rmfield(parameters.PROC, 'exclude_epochs');
parameters.PROC = rmfield(parameters.PROC, 'excl_eps');
parameters.PROC = rmfield(parameters.PROC, 'excl_epochs_reset');
parameters.PROC = rmfield(parameters.PROC, 'exclude');
parameters.PROC = rmfield(parameters.PROC, 'excl_partly');
parameters.PROC = rmfield(parameters.PROC, 'exclude_sats');

% Generic parameter templates must not activate sidecars from another input.
if isfield(parameters.PROC,'predicted_phase')
    parameters.PROC.predicted_phase.enable=false;
    parameters.PROC.predicted_phase.metadata_file='';
    parameters.PROC.predicted_phase.quality_rms_file='';
end
if isfield(parameters.PROC,'raim')
    parameters.PROC.raim.experiment_action='none';
    parameters.PROC.raim.calibration_file='';
    parameters.PROC.raim.validation_gps_week=NaN;
    parameters.PROC.raim.validation_start_sow=NaN;
    if isfield(parameters.PROC.raim,'calibration'); parameters.PROC.raim=rmfield(parameters.PROC.raim,'calibration'); end
end

