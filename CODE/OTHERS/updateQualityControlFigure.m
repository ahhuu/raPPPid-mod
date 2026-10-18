function updateQualityControlFigure(file)
% Maintainer helper: persist controls in GUIDE .fig without starting PPP.
if nargin<1; file=which('GUI_PPP.fig'); end
f=openfig(file,'new','invisible'); cleanup=onCleanup(@() close(f)); %#ok<NASGU>
if isempty(findall(f,'Tag','menu_quality_control'))
    uimenu(f,'Label','Advanced quality control','Tag','menu_quality_control', ...
        'Callback',@(s,~) GUI_QualityControl(ancestor(s,'figure')));
end
p=findall(f,'Tag','uipanel_weighting'); assert(isscalar(p)); bg=get(p,'BackgroundColor');
if isempty(findall(f,'Tag','checkbox_code_snr_f2'))
    uicontrol(p,'Style','checkbox','String','GPS f2 Code: SNR-dependent std', ...
        'Tag','checkbox_code_snr_f2','Units','normalized','Position',[.405 .245 .285 .042], ...
        'Value',0,'BackgroundColor',bg);
    labels={'C/N0 low/high:','Low std [m]:'}; tags={'text_code_snr_f2_low','text_code_snr_f2_std'};
    pos={[.405 .198 .130 .035],[.660 .198 .105 .035]};
    for k=1:2; uicontrol(p,'Style','text','String',labels{k},'Tag',tags{k}, ...
            'Units','normalized','Position',pos{k},'BackgroundColor',bg,'HorizontalAlignment','right'); end
    tags={'edit_code_snr_f2_low','edit_code_snr_f2_high','edit_code_snr_f2_std'};
    vals={'30','40','0.300'}; pos={[.540 .198 .050 .040],[.595 .198 .050 .040],[.775 .198 .065 .040]};
    for k=1:3; uicontrol(p,'Style','edit','String',vals{k},'Tag',tags{k},'Enable','off', ...
            'Units','normalized','Position',pos{k}); end
end
% openfig(...,'invisible') is only for editing. GUIDE restores the saved
applyParameterTooltips(f);
% visibility on launch, so never persist the temporary hidden state.
set(f,'Visible','on');
savefig(f,file);
fprintf('GUIDE_FIGURE_UPDATED\n');
end
