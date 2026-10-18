function finalizeRaimRegression20261006()
% Run only after the full serial action batch has exited.
root=fullfile(Path.RESULTS,'PPP_RAIM_ACTIONS_20261005');
diary(fullfile(root,'final_regression_console.txt'));
cleanup=onCleanup(@() diary('off')); %#ok<NASGU>
test_raim_code_monitor;
test_raim_numerics;
test_raim_code_action;
verifyRaimMonitorCompatibility20261005(fullfile(Path.RESULTS, ...
    'PPP_RAIM_REPLAY_20261005','manifest_20261005_230319.mat'));
names={'applyRaimCodeExperiment','raimTrialExclude','raimResidualTest', ...
    'runRaimPppActions20261005','evaluateRaimPppActions20261005'};
diagnostics=struct;
for k=1:numel(names)
    diagnostics.(names{k})=checkcode(which(names{k}),'-id');
    fprintf('CHECKCODE %s messages=%d\n',names{k},numel(diagnostics.(names{k})));
    disp(diagnostics.(names{k}));
end
save(fullfile(root,'final_checkcode.mat'),'diagnostics');
fprintf('FINAL_RAIM_REGRESSION_PASS\n');
end
