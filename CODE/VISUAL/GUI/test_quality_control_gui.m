function test_quality_control_gui(output_dir)
% Integration regression: edit/apply, MAT reload, defaults, all tab layouts.
if nargin<1; output_dir=tempname; end
if ~isfolder(output_dir); mkdir(output_dir); end
% GUIDE uses the FIG's saved visibility for ordinary launches.
saved_figure=openfig(which('GUI_PPP.fig'),'new','auto');
saved_visible=get(saved_figure,'Visible'); delete(saved_figure);
assert(strcmp(saved_visible,'on'),'GUIDE FIG must be saved visible for raPPPid startup.');
old_visible=get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanup=onCleanup(@() set(groot,'DefaultFigureVisible',old_visible)); %#ok<NASGU>
f=GUI_PPP('Visible','off'); figure_cleanup=onCleanup(@() closeIfValid(f)); %#ok<NASGU>
h=guidata(f); s=getSettingsFromGUI(h);
assert(isfield(h,'menu_quality_control') && isfield(h,'checkbox_code_snr_f2'));
% Unknown switches must not be inherited from settings MAT.
s.PROC.private_experiment=true;
h=setSettingsToGUI(s,h,true); guidata(f,h);
current=getSettingsFromGUI(h);
assert(~isfield(current.PROC,'private_experiment'));
d=GUI_QualityControl(f); controls=getappdata(d,'QualityControls'); rows=qualityControlSchema();
assert(isequal(GUI_QualityControl(f),d),'Duplicate settings dialog.');
set(findobj(d,'Tag','OTHER_CS_D_robust'),'Value',1);
set(findobj(d,'Tag','PROC_cold_start_window_epochs'),'String','19');
set(findobj(d,'Tag','PROC_predicted_phase_allowed_signals'),'String','G:L1C,C:L2I');
tabs=findobj(d,'Type','uitab');
for k=1:numel(tabs)
    set(get(tabs(k),'Parent'),'SelectedTab',tabs(k)); drawnow;
    saveas(d,fullfile(output_dir,sprintf('tab_%02d.png',k)));
end
assert(numel(controls)==size(rows,1));
button=findobj(d,'Tag','quality_apply'); callback=get(button,'Callback'); callback(button,[]);
assert(~ishghandle(d),'Apply did not close the valid dialog.');
h=guidata(f); saved=getSettingsFromGUI(h);
assert(saved.OTHER.CS.D_robust && saved.PROC.cold_start.window_epochs==19);
assert(isequal(saved.PROC.predicted_phase.allowed_signals,{'G:L1C','C:L2I'}));
file=fullfile(output_dir,'gui_settings.mat'); settings=saved; save(file,'settings');
loaded=load(file,'settings'); h=setSettingsToGUI(loaded.settings,h,true); guidata(f,h);
again=getSettingsFromGUI(h);
for k=1:size(rows,1)
    [~,a]=qualityControlField(saved,rows{k,2}); [~,b]=qualityControlField(again,rows{k,2});
    assert(isequaln(a,b),['MAT round trip: ' rows{k,2}]);
end
% Loading an older settings MAT must reset absent fields, not retain old UI state.
old=s; old.PROC=rmfield(old.PROC,{'cold_start','predicted_phase','raim'});
old.OTHER.CS=rmfield(old.OTHER.CS,{'D_robust','D_mad_factor','D_freq_enable','D_system_freq_enable', ...
    'TDCP_log_only','TDCP_z_factor','TDCP_min_sats','TDCP_max_reject'});
h=setSettingsToGUI(old,h,true); again=getSettingsFromGUI(h);
assert(~again.PROC.cold_start.enable && ~again.PROC.raim.enable && ~again.OTHER.CS.D_robust);
% Generic templates must not bind another dataset's sidecars.
saved.PROC.predicted_phase.enable=true; saved.PROC.predicted_phase.metadata_file='bound.csv';
saved.PROC.raim.experiment_action='exclude_code'; saved.PROC.raim.calibration_file='bound.mat';
p=settings2parameters(saved);
assert(~p.PROC.predicted_phase.enable && isempty(p.PROC.predicted_phase.metadata_file));
assert(strcmp(p.PROC.raim.experiment_action,'none') && isempty(p.PROC.raim.calibration_file));
fprintf('test_quality_control_gui: PASS (%d fields, %d tabs)\n',size(rows,1),numel(tabs));
end
function closeIfValid(f)
if ishghandle(f); close(f); end
end
