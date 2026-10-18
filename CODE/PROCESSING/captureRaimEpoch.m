function captureRaimEpoch(Epoch,Adjust,settings,elevation)
%CAPTURERAIMEPOCH Opt-in sampled, pre-update matrices for offline replay.
cfg = settings.PROC.raim;
if ~isfield(cfg,'capture_stride') || cfg.capture_stride <= 0; return; end
stride = cfg.capture_stride;
assert(isscalar(stride) && isfinite(stride) && stride == round(stride));
if mod(Epoch.q-1,stride) ~= 0; return; end
snapshot.version = 2;
snapshot.epoch = Epoch.q;
snapshot.gps_time = Epoch.gps_time;
snapshot.Epoch = struct('sats',Epoch.sats,'exclude',Epoch.exclude);
snapshot.Adjust = struct('A',Adjust.A,'Q',Adjust.Q,'omc',Adjust.omc, ...
    'NO_PARAM',Adjust.NO_PARAM,'param',Adjust.param, ...
    'param_pred',Adjust.param_pred,'param_sigma_pred',Adjust.param_sigma_pred);
snapshot.settings = struct('PROC',struct('method',settings.PROC.method,'raim',cfg), ...
    'INPUT',struct('proc_freqs',settings.INPUT.proc_freqs));
snapshot.elevation_deg = elevation(:,1);
snapshot.cn0 = NaN(numel(Epoch.sats),settings.INPUT.proc_freqs);
for f = 1:min(3,settings.INPUT.proc_freqs)
    name = sprintf('S%d',f);
    if isfield(Epoch,name) && numel(Epoch.(name)) == numel(Epoch.sats)
        snapshot.cn0(:,f) = Epoch.(name)(:);
    end
end
folder = fullfile(settings.PROC.output_dir,'raim_replay');
if ~isfolder(folder); mkdir(folder); end
save(fullfile(folder,sprintf('epoch_%06d.mat',Epoch.q)),'snapshot');
end
