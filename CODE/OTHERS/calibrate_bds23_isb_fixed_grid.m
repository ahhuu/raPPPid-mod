function varargout = calibrate_bds23_isb_fixed_grid(varargin)
% calibrate_bds23_isb_fixed_grid  Sweep fixed BDS2/3 ISB and find robust recommendation
%
% This utility runs PPP_main repeatedly with different
% settings.BIASES.bds23_isb_fixed_m values and evaluates coordinate RMS.
% It produces per-session best fixed value(s) and an aggregated device-level
% recommendation.
%
% Usage examples:
%   report = calibrate_bds23_isb_fixed_grid();
%   report = calibrate_bds23_isb_fixed_grid('obsFiles', {'D:/obs/a.obs','D:/obs/b.obs'});
%   report = calibrate_bds23_isb_fixed_grid('fixedGrid', 0:0.05:1, 'weights', [1 1 1]);
%   report = calibrate_bds23_isb_fixed_grid('deviceName', 'K181', 'skipEpochs', 0);
%
% Name-Value options:
%   settingsFile : path to settings.mat (default: WORK/settings.mat)
%   obsFiles     : char or cellstr, observation file(s). Empty -> use settings.INPUT.file_obs
%   fixedGrid    : vector in meters (default: 0:0.05:1)
%   weights      : [wH wN wE] in objective J = wH*RMS_H^2 + wN*RMS_N^2 + wE*RMS_E^2
%   skipEpochs   : epochs to skip after first valid solution (default: 0)
%   deviceName   : label for summary folder/report (default: 'device')
%   outputRoot   : report output root folder (default: RESULTS/ISB_FIXED_CAL)
%   procName     : base path for settings.PROC.name (suffix ISBFIXED_<fixed> is auto-appended)
%   interactive  : true/false, pop-up wizard for obs/parameters (default: true when no inputs)
%   useParallel  : true/false, parallel exhaustive sweep if toolbox available (default: true)
%   requireTrueReference : true/false, require valid settings.PLOT.pos_true (default: true)
%   maxRMS       : [maxH maxN maxE] in meters, feasibility threshold (default: [0.2 0.2 0.2])
%
% Output report struct contains session table, grid table, recommendation,
% output folder, and used options.

opts = parseInputs(varargin{:});
global STOP_CALC
report = [];

if opts.interactive
    [opts, canceled] = interactiveSelectSettingsFile(opts);
    if canceled
        fprintf('\nCalibration canceled by user.\n');
        report = [];
        if nargout > 0
            varargout{1} = report;
        end
        return;
    end
end

if ~exist(opts.settingsFile, 'file')
    error('settings file not found: %s', opts.settingsFile);
end

loaded = load(opts.settingsFile, 'settings');
if ~isfield(loaded, 'settings')
    error('No variable "settings" found in %s', opts.settingsFile);
end
base_settings = loaded.settings;

if opts.interactive
    [opts, base_settings, canceled] = interactiveSetup(opts, base_settings);
    if canceled
        fprintf('\nCalibration canceled by user.\n');
        report = [];
        if nargout > 0
            varargout{1} = report;
        end
        return;
    end
end

if isempty(opts.obsFiles)
    if isfield(base_settings, 'INPUT') && isfield(base_settings.INPUT, 'file_obs') && ~isempty(base_settings.INPUT.file_obs)
        opts.obsFiles = {base_settings.INPUT.file_obs};
    else
        error('obsFiles is empty and settings.INPUT.file_obs is not available.');
    end
end

if ischar(opts.obsFiles) || isstring(opts.obsFiles)
    opts.obsFiles = {char(opts.obsFiles)};
end

if isempty(opts.fixedGrid) || ~isnumeric(opts.fixedGrid)
    error('fixedGrid must be a numeric vector.');
end

if numel(opts.weights) ~= 3 || any(~isfinite(opts.weights))
    error('weights must be [wH wN wE].');
end

if numel(opts.maxRMS) ~= 3 || any(~isfinite(opts.maxRMS))
    error('maxRMS must be [maxH maxN maxE].');
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
out_dir = fullfile(opts.outputRoot, sprintf('%s_%s', opts.deviceName, timestamp));
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

fprintf('\n=== ISB Fixed Grid Calibration ===\n');
fprintf('Device: %s\n', opts.deviceName);
fprintf('Sessions: %d\n', numel(opts.obsFiles));
fprintf('Grid: [%g ... %g], step~%g m, N=%d\n', ...
    opts.fixedGrid(1), opts.fixedGrid(end), median(diff(opts.fixedGrid)), numel(opts.fixedGrid));
fprintf('Objective weights [H N E] = [%.3f %.3f %.3f]\n', opts.weights(1), opts.weights(2), opts.weights(3));
fprintf('RMS constraints [H N E] <= [%.3f %.3f %.3f] m\n', opts.maxRMS(1), opts.maxRMS(2), opts.maxRMS(3));
fprintf('Require true reference: %d\n', opts.requireTrueReference);
fprintf('Output: %s\n\n', out_dir);

% Extract device code from deviceName (e.g., "K181_trueRef" -> "K181")
device_code = opts.deviceName;
idx_underscore = strfind(device_code, '_');
if ~isempty(idx_underscore)
    device_code = device_code(1:idx_underscore(1)-1);
end

session_rows = {};
grid_rows = {};

parallelReady = false;
if opts.useParallel
    parallelReady = initParallelPool();
    if parallelReady
        fprintf('Parallel mode: ON (exhaustive grid, same optimum, faster wall time)\n');
    else
        fprintf('Parallel mode: unavailable, fallback to serial\n');
    end
end

for iSession = 1:numel(opts.obsFiles)
    obs_file = opts.obsFiles{iSession};
    if ~exist(obs_file, 'file')
        warning('obs file not found, skip: %s', obs_file);
        continue;
    end

    [~, session_name, ext] = fileparts(obs_file);
    session_name = [session_name ext];
    fprintf('--- Session %d/%d: %s ---\n', iSession, numel(opts.obsFiles), session_name);

    nGrid = numel(opts.fixedGrid);
    run_metrics = NaN(nGrid, 10); % [fixed, rmsH, rmsN, rmsE, J, nUsed, nValid, ok, usedTrueRef, feasible]
    grid_rows_session = cell(nGrid, 12);
    log_lines = cell(nGrid, 1);

    if parallelReady
        parfor iGrid = 1:nGrid
            fixed_m = opts.fixedGrid(iGrid);
            [metricsRow, gridRow, logLine] = evaluateSingleFixed(base_settings, opts, fixed_m, obs_file, session_name, device_code);
            run_metrics(iGrid, :) = metricsRow;
            grid_rows_session(iGrid, :) = gridRow;
            log_lines{iGrid} = logLine;
        end
        for iGrid = 1:nGrid
            fprintf('%s', log_lines{iGrid});
        end
    else
        for iGrid = 1:nGrid
            fixed_m = opts.fixedGrid(iGrid);
            [metricsRow, gridRow, logLine] = evaluateSingleFixed(base_settings, opts, fixed_m, obs_file, session_name, device_code);
            run_metrics(iGrid, :) = metricsRow;
            grid_rows_session(iGrid, :) = gridRow;
            fprintf('%s', logLine);
        end
    end

    idx_ok = find(run_metrics(:,8) == 1 & isfinite(run_metrics(:,5)));
    if isempty(idx_ok)
        warning('No valid runs for session %s', session_name);
        grid_rows = [grid_rows; grid_rows_session]; %#ok<AGROW>
        continue;
    end

    grid_rows = [grid_rows; grid_rows_session]; %#ok<AGROW>

    idx_feasible = find(run_metrics(:,10) == 1 & isfinite(run_metrics(:,5)));
    used_constraint = true;
    if isempty(idx_feasible)
        used_constraint = false;
        warning('No run satisfies RMS constraints for session %s. Fallback to minimum J among valid runs.', session_name);
        idx_pick = idx_ok;
    else
        idx_pick = idx_feasible;
    end

    [~, k] = min(run_metrics(idx_pick,5));
    idx_best = idx_pick(k);
    best_fixed = run_metrics(idx_best,1);
    best_rmsH  = run_metrics(idx_best,2);
    best_rmsN  = run_metrics(idx_best,3);
    best_rmsE  = run_metrics(idx_best,4);
    best_J     = run_metrics(idx_best,5);

    session_rows(end+1, :) = {opts.deviceName, session_name, best_fixed, best_rmsH, best_rmsN, best_rmsE, best_J, logical(used_constraint)}; %#ok<AGROW>

    f = figure('Visible','off', 'Name', ['ISB Fixed Sweep - ' session_name], 'NumberTitle', 'off');
    tiledlayout(2,1);
    nexttile;
    plot(run_metrics(:,1), run_metrics(:,2), 'g-', 'LineWidth', 1.2); hold on;
    plot(run_metrics(:,1), run_metrics(:,3), 'r-', 'LineWidth', 1.2);
    plot(run_metrics(:,1), run_metrics(:,4), 'b-', 'LineWidth', 1.2);
    xline(best_fixed, 'k--', 'LineWidth', 1.2);
    grid on; xlabel('fixed ISB [m]'); ylabel('RMS [m]');
    legend('RMS_H','RMS_N','RMS_E','best fixed', 'Location','best');
    title(sprintf('%s | best fixed=%+.3f m', session_name, best_fixed), 'Interpreter','none');

    nexttile;
    plot(run_metrics(:,1), run_metrics(:,5), 'm-', 'LineWidth', 1.4); hold on;
    xline(best_fixed, 'k--', 'LineWidth', 1.2);
    grid on; xlabel('fixed ISB [m]'); ylabel('J');
    title(sprintf('Objective J (w=[%.2f %.2f %.2f])', opts.weights(1), opts.weights(2), opts.weights(3)));

    saveas(f, fullfile(out_dir, sprintf('sweep_%s.png', sanitizeName(session_name))));
    close(f);
end

if isempty(session_rows)
    error('No valid session results were produced.');
end

T_session = cell2table(session_rows, 'VariableNames', ...
    {'device','session','best_fixed_m','rmsH_m','rmsN_m','rmsE_m','J','satisfyConstraints'});
T_grid = cell2table(grid_rows, 'VariableNames', ...
    {'device','session','fixed_m','rmsH_m','rmsN_m','rmsE_m','J','nUsed','nValid','ok','usedTrueReference','feasible'});

best_vals = T_session.best_fixed_m;
ISB0 = median(best_vals, 'omitnan');
MAD = median(abs(best_vals - ISB0), 'omitnan');
p10 = localPrctile(best_vals, 10);
p90 = localPrctile(best_vals, 90);

gridMin = min(opts.fixedGrid);
gridMax = max(opts.fixedGrid);
tolGrid = max(1e-12, (gridMax-gridMin)*1e-9);
isRecAtEdge = abs(ISB0-gridMin) <= tolGrid || abs(ISB0-gridMax) <= tolGrid;
isAnyBestAtEdge = any(abs(best_vals-gridMin) <= tolGrid | abs(best_vals-gridMax) <= tolGrid);
needExpandHint = isRecAtEdge || isAnyBestAtEdge;

expandHint = '';
if needExpandHint
    expandHint = sprintf('Hint: best fixed hits grid edge [%.3f, %.3f] m; consider extending search range.', gridMin, gridMax);
end

rec = struct();
rec.ISB0_m = ISB0;
rec.MAD_m = MAD;
rec.P10_m = p10;
rec.P90_m = p90;
rec.recommended_search_low_m = ISB0 - 0.3;
rec.recommended_search_high_m = ISB0 + 0.3;
rec.recommended_constrained_prior_m = ISB0;
rec.recommended_constrained_sigma_m = max(0.2, 3*MAD);
rec.need_expand_search_hint = needExpandHint;
rec.expand_search_hint = expandHint;

csv_session = fullfile(out_dir, 'session_best.csv');
csv_grid = fullfile(out_dir, 'grid_all.csv');
header_session = {
    'session_best.csv', ...
    'satisfyConstraints: 1=best fixed selected from feasible candidates; 0=no feasible candidate, fallback to minimum J among valid runs.' ...
    };
header_grid = {
    'grid_all.csv', ...
    'nValid: number of valid epochs before skipping.', ...
    'nUsed: number of epochs actually used for RMS after skipEpochs.', ...
    'ok: 1=evaluation succeeded and RMS is valid; 0=failed/invalid.', ...
    'usedTrueReference: 1=true reference from Coords.txt or settings.PLOT.pos_true used; 0=not used.', ...
    'feasible: 1=ok && usedTrueReference && RMS_H/N/E <= maxRMS; 0=otherwise.' ...
    };

writeCsvWithHeader(csv_session, header_session, T_session);
writeCsvWithHeader(csv_grid, header_grid, T_grid);

report = struct();
report.options = opts;
report.output_dir = out_dir;
report.session_best = T_session;
report.grid_all = T_grid;
report.recommendation = rec;

save(fullfile(out_dir, 'report.mat'), 'report');

txt_file = fullfile(out_dir, 'summary.txt');
fid = fopen(txt_file, 'w');
fprintf(fid, 'ISB fixed grid calibration summary\n');
fprintf(fid, 'Device: %s\n', opts.deviceName);
fprintf(fid, 'Sessions used: %d\n', height(T_session));
fprintf(fid, 'Fixed grid: [%g ... %g], N=%d\n', opts.fixedGrid(1), opts.fixedGrid(end), numel(opts.fixedGrid));
fprintf(fid, 'Weights [H N E]: [%.3f %.3f %.3f]\n\n', opts.weights(1), opts.weights(2), opts.weights(3));
fprintf(fid, 'Require true reference: %d\n', opts.requireTrueReference);
fprintf(fid, 'RMS constraints [H N E] <= [%.3f %.3f %.3f] m\n\n', opts.maxRMS(1), opts.maxRMS(2), opts.maxRMS(3));
fprintf(fid, 'Recommended ISB0 (median of session-best): %+0.4f m\n', rec.ISB0_m);
fprintf(fid, 'MAD: %0.4f m\n', rec.MAD_m);
fprintf(fid, 'P10/P90: [%+0.4f, %+0.4f] m\n', rec.P10_m, rec.P90_m);
fprintf(fid, 'Suggested online micro-search: [%+0.4f, %+0.4f] m\n', rec.recommended_search_low_m, rec.recommended_search_high_m);
fprintf(fid, 'Suggested constrained prior/sigma: prior=%+0.4f m, sigma=%0.4f m\n\n', ...
    rec.recommended_constrained_prior_m, rec.recommended_constrained_sigma_m);
if rec.need_expand_search_hint
    fprintf(fid, '%s\n\n', rec.expand_search_hint);
end
fprintf(fid, 'Per-session best:\n');
for i = 1:height(T_session)
    fprintf(fid, '  %s | best=%+0.4f m | RMS(H,N,E)=(%.3f, %.3f, %.3f) m | J=%.6f | constrained=%d\n', ...
        T_session.session{i}, T_session.best_fixed_m(i), T_session.rmsH_m(i), T_session.rmsN_m(i), T_session.rmsE_m(i), T_session.J(i), T_session.satisfyConstraints(i));
end
fclose(fid);

fprintf('\n=== Calibration finished ===\n');
fprintf('Recommended ISB0: %+0.4f m (MAD=%0.4f m, P10/P90=[%+0.4f,%+0.4f])\n', ...
    rec.ISB0_m, rec.MAD_m, rec.P10_m, rec.P90_m);
fprintf('Suggested constrained sigma: %0.4f m\n', rec.recommended_constrained_sigma_m);
if rec.need_expand_search_hint
    fprintf('%s\n', rec.expand_search_hint);
end
fprintf('Saved: %s\n', out_dir);

if nargout > 0
    varargout{1} = report;
end

end


function opts = parseInputs(varargin)
opts = struct();
opts.settingsFile = fullfile('WORK', 'settings.mat');
opts.obsFiles = {};
opts.fixedGrid = 0:0.05:1;
opts.weights = [1 1 1];
opts.skipEpochs = 0;
opts.deviceName = 'device';
opts.outputRoot = fullfile('RESULTS', 'ISB_FIXED_CAL');
opts.procName = '';
opts.interactive = isempty(varargin);
opts.useParallel = true;
opts.requireTrueReference = true;
opts.maxRMS = [0.2 0.2 0.2];

if mod(numel(varargin),2) ~= 0
    error('Inputs must be name-value pairs.');
end

for i = 1:2:numel(varargin)
    key = lower(string(varargin{i}));
    val = varargin{i+1};
    switch key
        case "settingsfile"
            opts.settingsFile = val;
        case "obsfiles"
            opts.obsFiles = val;
        case "fixedgrid"
            opts.fixedGrid = val;
        case "weights"
            opts.weights = val;
        case "skipepochs"
            opts.skipEpochs = val;
        case "devicename"
            opts.deviceName = val;
        case "outputroot"
            opts.outputRoot = val;
        case {"procname", "processname", "procnameoverride"}
            opts.procName = val;
        case "interactive"
            opts.interactive = logical(val);
        case {"useparallel", "parallel"}
            opts.useParallel = logical(val);
        case "requiretruereference"
            opts.requireTrueReference = logical(val);
        case "maxrms"
            opts.maxRMS = val;
        otherwise
            error('Unknown option: %s', key);
    end
end

opts.settingsFile = char(opts.settingsFile);
opts.deviceName = char(opts.deviceName);
opts.outputRoot = char(opts.outputRoot);
opts.procName = char(opts.procName);
opts.fixedGrid = opts.fixedGrid(:)';
opts.weights = double(opts.weights(:))';
opts.skipEpochs = double(opts.skipEpochs);
opts.maxRMS = double(opts.maxRMS(:))';

if ~exist(opts.outputRoot, 'dir')
    mkdir(opts.outputRoot);
end
end


function [opts, canceled] = interactiveSelectSettingsFile(opts)
canceled = false;

if ~usejava('desktop')
    error('Interactive mode requires MATLAB desktop. Run with explicit name-value parameters in batch mode.');
end

defaultDir = fullfile('WORK', 'PARAMETERS');
if ~exist(defaultDir, 'dir')
    defaultDir = fullfile(pwd, 'WORK', 'PARAMETERS');
end
if ~exist(defaultDir, 'dir')
    defaultDir = fileparts(opts.settingsFile);
end
if isempty(defaultDir) || ~exist(defaultDir, 'dir')
    defaultDir = pwd;
end

wizardCache = loadWizardCache(opts.settingsFile);
defaultSettingsFile = fullfile(defaultDir, 'settings.mat');
if isfield(wizardCache, 'lastSettingsFile') && ~isempty(wizardCache.lastSettingsFile) && exist(wizardCache.lastSettingsFile, 'file')
    defaultSettingsFile = wizardCache.lastSettingsFile;
end

[f, p] = uigetfile({'*.mat', 'MAT-files (*.mat)'; '*.*', 'All files (*.*)'}, ...
    'Select settings MAT file (must contain variable "settings")', ...
    defaultSettingsFile);

if isequal(f, 0)
    canceled = true;
    return;
end

opts.settingsFile = fullfile(p, f);
fprintf('Using settings file: %s\n', opts.settingsFile);
end


function [opts, base_settings, canceled] = interactiveSetup(opts, base_settings)
canceled = false;

if ~usejava('desktop')
    error('Interactive mode requires MATLAB desktop. Run with explicit name-value parameters in batch mode.');
end

% Load cached wizard inputs from last run (if available)
wizardCache = loadWizardCache(opts.settingsFile);

% 1) Select observation file(s)
defaultObsDir = fullfile('..', 'DATA', 'OBS');
if isfield(wizardCache, 'lastObsDir') && ~isempty(wizardCache.lastObsDir) && exist(wizardCache.lastObsDir, 'dir')
    defaultObsDir = wizardCache.lastObsDir;
end
if ~exist(defaultObsDir, 'dir')
    defaultObsDir = pwd;
end

[obsFiles, obsPath] = uigetfile( ...
    {'*.o;*.obs;*.rnx;*.yyo;*.*', 'RINEX observation files (*.*)'; '*.*', 'All files (*.*)'}, ...
    'Select observation file(s)', defaultObsDir, 'MultiSelect', 'on');

if isequal(obsFiles, 0)
    canceled = true;
    return;
end

if ischar(obsFiles)
    opts.obsFiles = {fullfile(obsPath, obsFiles)};
else
    opts.obsFiles = cellfun(@(f) fullfile(obsPath, f), obsFiles, 'UniformOutput', false);
end

% 2) Parameter dialog
baseProcName = '';
if isfield(base_settings, 'PROC') && isfield(base_settings.PROC, 'name') && ~isempty(base_settings.PROC.name)
    baseProcName = char(base_settings.PROC.name);
end

defaultDevice = inferDeviceName(base_settings, baseProcName);
defaultProcName = buildProcNameOverride(baseProcName, defaultDevice);

fprintf('\n[Interactive Setup] 参数说明:\n');
fprintf('  deviceName            : 设备站点标识（用于 Coords.txt 匹配）\n');
fprintf('  settings.PROC.name    : 解算输出基路径\n');
fprintf('  fixedGrid             : 扫描固定值网格（米）\n');
fprintf('  weights [H N E]       : 目标函数 J 各方向权重\n');
fprintf('  skipEpochs            : 丢弃前 N 个有效历元\n');
fprintf('  useParallel           : 1=并行穷举（需MATLAB Parallel Computing Toolbox）\n');
fprintf('  requireTrueReference  : 1=必须真实坐标，0=允许回退中位值\n');
fprintf('  maxRMS [H N E]        : 三方向 RMS 上限阈值（米）（无上限[inf inf inf]）\n');
fprintf('  outputRoot            : 校准汇总输出目录\n\n');

prompts = {
    'deviceName (e.g. K181):', ...
    'settings.PROC.name base path (e.g. GREC-K70/K181/ISB_FIXED_CAL):', ...
    'fixedGrid (MATLAB vector, e.g. 0:0.05:1):', ...
    'weights [H N E] (e.g. [1 1 1]):', ...
    'skipEpochs (e.g. 0):', ...
    'useParallel (1/0):', ...
    'requireTrueReference (1/0):', ...
    'maxRMS [H N E] in m (e.g. [0.2 0.2 0.2]):', ...
    'outputRoot:' ...
    };

defaults = {
    defaultDevice, ...
    defaultProcName, ...
    formatGridForInput(opts.fixedGrid), ...
    mat2str(opts.weights), ...
    num2str(opts.skipEpochs), ...
    num2str(double(opts.useParallel)), ...
    num2str(double(opts.requireTrueReference)), ...
    mat2str(opts.maxRMS), ...
    opts.outputRoot ...
    };

answer = inputdlg(prompts, 'ISB Fixed Calibration Setup', [1 100], defaults, 'on');
if isempty(answer)
    canceled = true;
    return;
end


function txt = formatGridForInput(grid)
txt = mat2str(grid);

if ~isnumeric(grid) || isempty(grid)
    return;
end

g = double(grid(:)');
if numel(g) < 3
    return;
end

d = diff(g);
step = median(d);
tol = max(1e-12, abs(step) * 1e-9);

if all(abs(d - step) <= tol)
    txt = sprintf('%g:%g:%g', g(1), step, g(end));
end
end

opts.deviceName = strtrim(answer{1});
opts.procName = strtrim(answer{2});

tmp = str2num(answer{3}); %#ok<ST2NM>
if isempty(tmp) || ~isnumeric(tmp)
    error('Invalid fixedGrid input. Example: 0:0.1:1');
end
opts.fixedGrid = tmp(:)';

tmp = str2num(answer{4}); %#ok<ST2NM>
if isempty(tmp) || numel(tmp) ~= 3
    error('Invalid weights input. Example: [1 1 1]');
end
opts.weights = double(tmp(:))';

tmp = str2double(answer{5});
if ~isfinite(tmp) || tmp < 0
    error('Invalid skipEpochs input. Example: 0');
end
opts.skipEpochs = tmp;

tmp = str2double(answer{6});
if ~isfinite(tmp)
    error('Invalid useParallel input. Use 1 or 0');
end
opts.useParallel = logical(tmp);

tmp = str2double(answer{7});
if ~isfinite(tmp)
    error('Invalid requireTrueReference input. Use 1 or 0');
end
opts.requireTrueReference = logical(tmp);

tmp = str2num(answer{8}); %#ok<ST2NM>
if isempty(tmp) || numel(tmp) ~= 3
    error('Invalid maxRMS input. Example: [0.2 0.2 0.2]');
end
opts.maxRMS = double(tmp(:))';

opts.outputRoot = strtrim(answer{9});

if isempty(opts.deviceName)
    error('deviceName cannot be empty.');
end
if isempty(opts.outputRoot)
    error('outputRoot cannot be empty.');
end

% Keep settings aligned with user selections
if isfield(base_settings, 'INPUT')
    base_settings.INPUT.file_obs = opts.obsFiles{1};
end
if ~isempty(opts.procName)
    if ~isfield(base_settings, 'PROC') || ~isstruct(base_settings.PROC)
        base_settings.PROC = struct();
    end
    base_settings.PROC.name = composeProcNameWithFixed(opts.procName, 0);
end

% Save wizard inputs for next run auto-fill
wizardCache = struct();
% Only remember navigation convenience (not parameter values)
wizardCache.lastObsDir = obsPath;
wizardCache.lastSettingsFile = opts.settingsFile;
saveWizardCache(opts.settingsFile, wizardCache);
end


function deviceName = inferDeviceName(base_settings, baseProcName)
deviceName = '';

if nargin >= 2 && ~isempty(baseProcName)
    parts = strsplit(char(baseProcName), '/');
    if numel(parts) >= 2
        cand = strtrim(parts{2});
        if ~isempty(cand) && ~strcmp(cand, '$stat')
            deviceName = cand;
        end
    end
end

if isempty(deviceName) && isfield(base_settings, 'INPUT')
    inputCfg = base_settings.INPUT;
    if isfield(inputCfg, 'stat_name') && ~isempty(inputCfg.stat_name)
        deviceName = char(inputCfg.stat_name);
    elseif isfield(inputCfg, 'statName') && ~isempty(inputCfg.statName)
        deviceName = char(inputCfg.statName);
    elseif isfield(inputCfg, 'station_name') && ~isempty(inputCfg.station_name)
        deviceName = char(inputCfg.station_name);
    end
end

deviceName = strtrim(deviceName);
if isempty(deviceName)
    deviceName = 'K181';
end
end


function procName = buildProcNameOverride(baseProcName, deviceName)
prefix = 'GREC-K70';

if nargin >= 1 && ~isempty(baseProcName)
    parts = strsplit(char(baseProcName), '/');
    if ~isempty(parts) && ~isempty(strtrim(parts{1}))
        prefix = strtrim(parts{1});
    end
end

procName = sprintf('%s/%s/ISB_FIXED_CAL', prefix, strtrim(deviceName));
end


function procName = composeProcNameWithFixed(procNameBase, fixed_m)
base = char(strtrim(procNameBase));

% If user accidentally passed a previous ISBFIXED_* suffix, strip it first
base = regexprep(base, '/ISBFIXED_.*$', '');

fixedStr = sprintf('%g', fixed_m);
if strcmp(fixedStr, '-0')
    fixedStr = '0';
end

procName = sprintf('%s/ISBFIXED_%s', base, fixedStr);
end


function cache = loadWizardCache(settingsFile)
cache = struct();
cacheFile = getWizardCacheFile(settingsFile);
if isempty(cacheFile) || ~exist(cacheFile, 'file')
    return;
end

try
    loaded = load(cacheFile, 'wizardCache');
    if isfield(loaded, 'wizardCache') && isstruct(loaded.wizardCache)
        cache = loaded.wizardCache;
    end
catch
    % ignore cache read errors
end
end


function saveWizardCache(settingsFile, wizardCache)
cacheFile = getWizardCacheFile(settingsFile);
if isempty(cacheFile)
    return;
end

try
    save(cacheFile, 'wizardCache');
catch
    % ignore cache write errors
end
end


function cacheFile = getWizardCacheFile(settingsFile)
% Keep one stable cache file so defaults persist across different settings files
cacheFile = '';

scriptDir = fileparts(mfilename('fullpath'));           % .../CODE/OTHERS
codeDir = fileparts(scriptDir);                         % .../CODE
repoRoot = fileparts(codeDir);                          % .../raPPPid
preferredDir = fullfile(repoRoot, 'WORK');

if isfolder(preferredDir)
    baseDir = preferredDir;
else
    baseDir = pwd;
end

cacheFile = fullfile(baseDir, 'calibrate_bds23_isb_fixed_grid_last.mat');
end


function ok = initParallelPool()
ok = false;
try
    if ~license('test', 'Distrib_Computing_Toolbox')
        return;
    end
    p = gcp('nocreate');
    if isempty(p)
        try
            parpool('Processes');
        catch
            try
                parpool;
            catch
                parpool('threads');
            end
        end
    end
    ok = true;
catch
    ok = false;
end
end


function [metricsRow, gridRow, logLine] = evaluateSingleFixed(base_settings, opts, fixed_m, obs_file, session_name, device_code)
s = base_settings;
s.INPUT.file_obs = obs_file;
if ~isempty(opts.procName)
    if ~isfield(s, 'PROC') || ~isstruct(s.PROC)
        s.PROC = struct();
    end
    s.PROC.name = composeProcNameWithFixed(opts.procName, fixed_m);
end
s.BIASES.estimate_bds23_isb = true;
s.BIASES.bds23_isb_mode = 'fixed';
s.BIASES.bds23_isb_fixed_m = fixed_m;

if isfield(s, 'EXP') && isfield(s.EXP, 'data4plot')
    s.EXP.data4plot = true;
end

if isfield(s, 'PLOT')
    pfs = fieldnames(s.PLOT);
    for ip = 1:numel(pfs)
        v = s.PLOT.(pfs{ip});
        if islogical(v) && isscalar(v)
            s.PLOT.(pfs{ip}) = false;
        end
    end
end

ok = true;
settings_after = [];
logParts = {};
failMsg = '';
global STOP_CALC
try
    STOP_CALC = 0;
    settings_after = PPP_main(s);
catch ME
    ok = false;
    failMsg = ME.message;
    warning('PPP_main failed at fixed=%.3f m, session=%s: %s', fixed_m, session_name, ME.message);
end

if ok && ~isempty(settings_after) && isfield(settings_after, 'PROC') && isfield(settings_after.PROC, 'output_dir')
    result_dir = settings_after.PROC.output_dir;
    logParts{end+1} = sprintf('=== Evaluation result ===\n'); %#ok<AGROW>
    logParts{end+1} = sprintf('result_dir: %s\n', result_dir); %#ok<AGROW>
    [rmsH, rmsN, rmsE, nUsed, nValid, okEval, usedTrueRef] = evaluateResult(result_dir, opts.skipEpochs, opts.requireTrueReference, device_code);
    if ~okEval
        ok = false;
        logParts{end+1} = sprintf('evaluateResult failed\n'); %#ok<AGROW>
    else
        logParts{end+1} = sprintf('usedTrueReference: %d\n', usedTrueRef); %#ok<AGROW>
    end
else
    rmsH = NaN; rmsN = NaN; rmsE = NaN; nUsed = 0; nValid = 0; usedTrueRef = 0;
end

if ok
    J = opts.weights(1)*rmsH^2 + opts.weights(2)*rmsN^2 + opts.weights(3)*rmsE^2;
else
    J = NaN;
end

feasible = logical(ok) && logical(usedTrueRef) && rmsH <= opts.maxRMS(1) && rmsN <= opts.maxRMS(2) && rmsE <= opts.maxRMS(3);
metricsRow = [fixed_m, rmsH, rmsN, rmsE, J, nUsed, nValid, ok, usedTrueRef, feasible];
gridRow = {opts.deviceName, session_name, fixed_m, rmsH, rmsN, rmsE, J, nUsed, nValid, logical(ok), logical(usedTrueRef), logical(feasible)};

if ok
    logParts{end+1} = sprintf('fixed=%+6.3f m -> RMS(H,N,E)=(%.3f, %.3f, %.3f) m, J=%.5f\n', fixed_m, rmsH, rmsN, rmsE, J); %#ok<AGROW>
else
    if ~isempty(failMsg)
        logParts{end+1} = sprintf('fixed=%+6.3f m -> FAILED (%s)\n', fixed_m, failMsg); %#ok<AGROW>
    else
        logParts{end+1} = sprintf('fixed=%+6.3f m -> FAILED\n', fixed_m); %#ok<AGROW>
    end
end

logLine = [logParts{:}];
end


function [rmsH, rmsN, rmsE, nUsed, nValid, ok, usedTrueReference] = evaluateResult(result_dir, skipEpochs, requireTrueReference, device_code)
rmsH = NaN; rmsN = NaN; rmsE = NaN; nUsed = 0; nValid = 0; ok = false; usedTrueReference = 0;
data_file = fullfile(result_dir, 'data4plot.mat');
if ~exist(data_file, 'file')
    warning('data4plot.mat not found in %s', result_dir);
    return;
end

loaded = load(data_file, 'storeData', 'settings');
if ~isfield(loaded, 'storeData') || ~isfield(loaded, 'settings')
    warning('Missing storeData/settings in %s', data_file);
    return;
end

storeData = loaded.storeData;
settings = loaded.settings;

if ~isfield(storeData, 'posFloat_utm') || isempty(storeData.posFloat_utm)
    warning('posFloat_utm missing in %s', data_file);
    return;
end

pos_utm = storeData.posFloat_utm;
if isfield(storeData, 'param')
    pos_cart = storeData.param(:,1:3);
else
    warning('param missing in %s', data_file);
    return;
end

% Try to get true position from Coords.txt first (using device_code)
xyz_true = NaN(3,1);
usedTrueReference = 0;
if nargin > 3 && ~isempty(device_code)
    xyz_true = loadTrueFromCoords(device_code);
    if all(isfinite(xyz_true))
        usedTrueReference = 1;  % Successfully loaded from Coords.txt
    fprintf('[DEBUG] Loaded XYZ from Coords.txt for device=%s: [%.3f, %.3f, %.3f]\n', device_code, xyz_true(1), xyz_true(2), xyz_true(3));
    end
end

% Fallback to settings.PLOT.pos_true if Coords.txt failed
if any(~isfinite(xyz_true))
    if isfield(settings, 'PLOT') && isfield(settings.PLOT, 'pos_true') && isnumeric(settings.PLOT.pos_true)
        xyz0 = settings.PLOT.pos_true(:);
        if numel(xyz0) >= 3 && all(isfinite(xyz0(1:3))) && ~any(xyz0(1:3)==0) && ~any(xyz0(1:3)==1)
            xyz_true = xyz0(1:3);
            usedTrueReference = 1;  % Fallback to settings reference
           fprintf('[DEBUG] Fallback: loaded XYZ from settings.PLOT.pos_true: [%.3f, %.3f, %.3f]\n', xyz_true(1), xyz_true(2), xyz_true(3));
        end
    end
end

% If still no valid reference, use median of float solution or fail
if any(~isfinite(xyz_true))
    if requireTrueReference
    fprintf('[DEBUG] No valid true reference found in Coords.txt (device=%s) or settings.PLOT.pos_true\n', device_code);
        warning('No valid true reference found in Coords.txt (device=%s) or settings.PLOT.pos_true for %s', device_code, result_dir);
        return;
    end
    % Fallback: use median of estimated positions (not a true reference)
    bool_zero = all(pos_cart == 0, 2);
    pos_cart(bool_zero, :) = [];
    if isempty(pos_cart)
        warning('No valid position samples to build fallback reference in %s', result_dir);
        return;
    end
    xyz_true = median(pos_cart, 1, 'omitnan')';
    usedTrueReference = 0;  % This is a fallback, not a true reference
    fprintf('[DEBUG] Using fallback: median of float positions (not true reference)\n');
end

pos_true_geo = cart2geo(xyz_true);
[North_true, East_true] = ell2utm_GT(pos_true_geo.lat, pos_true_geo.lon);

dN = pos_utm(:,1) - North_true;
dE = pos_utm(:,2) - East_true;
dH = pos_utm(:,3) - pos_true_geo.h;

if isfield(storeData, 'float')
    idx_valid = find(storeData.float ~= 0);
else
    idx_valid = find(any(pos_utm ~= 0, 2));
end
if isempty(idx_valid)
    warning('No valid float epochs in %s', result_dir);
    return;
end

nValid = numel(idx_valid);
if nValid <= skipEpochs
    warning('Not enough valid epochs in %s (valid=%d, skip=%d)', result_dir, nValid, skipEpochs);
    return;
end

idx_use = idx_valid(skipEpochs+1:end);
nUsed = numel(idx_use);

rmsH = calculate_rms(dH(idx_use));
rmsN = calculate_rms(dN(idx_use));
rmsE = calculate_rms(dE(idx_use));

ok = all(isfinite([rmsH, rmsN, rmsE]));
end


function p = localPrctile(x, q)
x = x(isfinite(x));
if isempty(x)
    p = NaN;
    return;
end
x = sort(x(:));
n = numel(x);
if n == 1
    p = x;
    return;
end
k = (q/100) * (n-1) + 1;
k0 = floor(k);
k1 = ceil(k);
if k0 == k1
    p = x(k0);
else
    a = k - k0;
    p = (1-a)*x(k0) + a*x(k1);
end
end


function xyz = loadTrueFromCoords(device_code)
% Load true coordinates from DATA/COORDS/Coords.txt for given device_code
% device_code: e.g., 'K181', 'K701', etc.
xyz = NaN(3,1);

if isempty(device_code)
    return;
end

% Find Coords.txt file
coords_file = fullfile(pwd, '..', 'DATA', 'COORDS', 'Coords.txt');
if ~exist(coords_file, 'file')
    coords_file = fullfile(pwd, 'DATA', 'COORDS', 'Coords.txt');
end
if ~exist(coords_file, 'file')
    % Try relative to workspace
    candidates = {
        fullfile(pwd, '..', '..', 'DATA', 'COORDS', 'Coords.txt'),
        fullfile(pwd, '..', 'DATA', 'COORDS', 'Coords.txt'),
        fullfile(pwd, 'DATA', 'COORDS', 'Coords.txt')
    };
    for i = 1:length(candidates)
        if exist(candidates{i}, 'file')
            coords_file = candidates{i};
            break;
        end
    end
end

if ~exist(coords_file, 'file')
    return;
end

try
    % Read Coords.txt line by line
    fid = fopen(coords_file, 'r');
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line) && ~isempty(line) && line(1) ~= '%'
            % Parse line: station, mjd, x, y, z
            % Use regular expression to extract values
            tokens = regexp(line, '\s+', 'split');
            tokens(cellfun(@isempty, tokens)) = [];  % Remove empty cells
            
            if numel(tokens) >= 5
                this_station = tokens{1};
                if strcmpi(this_station, device_code)
                    x = str2double(tokens{3});
                    y = str2double(tokens{4});
                    z = str2double(tokens{5});
                    if all(isfinite([x, y, z])) && any([x, y, z] ~= 0)
                        xyz = [x; y; z];
                    end
                    fclose(fid);
                    return;
                end
            end
        end
    end
    fclose(fid);
catch
    % Silently fail if parsing error
end
end


function out = sanitizeName(in)
out = regexprep(in, '[^a-zA-Z0-9_\-]', '_');
end


function writeCsvWithHeader(csvFile, headerLines, T)
fid = fopen(csvFile, 'w');
if fid < 0
    error('Cannot open file for writing: %s', csvFile);
end

for i = 1:numel(headerLines)
    fprintf(fid, '# %s\n', headerLines{i});
end
fprintf(fid, '#\n');
fclose(fid);

writetable(T, csvFile, 'WriteMode', 'append');
end
