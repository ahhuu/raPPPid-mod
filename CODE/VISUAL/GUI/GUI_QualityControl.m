function dialog = GUI_QualityControl(owner)
% Advanced quality controls belonging to one GUIDE window.
existing=findall(groot,'Type','figure','Tag','GUI_QualityControl');
for k=1:numel(existing)
    if isequal(getappdata(existing(k),'Owner'),owner); figure(existing(k)); dialog=existing(k); return; end
end
handles=guidata(owner); original=getSettingsFromGUI(handles);
original=applyQualityControlDefaults(original); rows=qualityControlSchema();
dialog=figure('Name','Advanced quality control','NumberTitle','off', ...
    'Tag','GUI_QualityControl','MenuBar','none','ToolBar','none', ...
    'Position',[150 150 900 630],'Resize','off','WindowStyle','normal');
setappdata(dialog,'Owner',owner);
uicontrol(dialog,'Style','text','Position',[15 588 870 28], ...
    'HorizontalAlignment','left','String', ...
    'Frequency slots follow the selected signals. Prediction uses external RINEX/CSV files. RAIM actions require frozen calibration.');
tabs=uitabgroup(dialog,'Units','pixels','Position',[15 105 870 475]);
groups=unique(rows(:,1),'stable'); controls=cell(size(rows,1),1);
for g=1:numel(groups)
    tab=uitab(tabs,'Title',groups{g}); indices=find(strcmp(rows(:,1),groups{g}));
    for j=1:numel(indices)
        i=indices(j); y=390-(j-1)*43; type=rows{i,5};
        [~,v]=qualityControlField(original,rows{i,2});
        tip=qualityControlTooltip(rows{i,2});
        uicontrol(tab,'Style','text','Position',[12 y 375 26],'HorizontalAlignment','left','String',rows{i,3},'TooltipString',tip);
        if iscell(type)
            ix=find(strcmp(v,type),1); if isempty(ix); ix=1; end
            controls{i}=uicontrol(tab,'Style','popupmenu','String',type,'Value',ix,'Position',[395 y 355 28]);
        elseif strcmp(type,'bool')
            controls{i}=uicontrol(tab,'Style','checkbox','Value',logical(v),'Position',[395 y 355 28]);
        else
            if strcmp(type,'signals'); value=strjoin(v,',');
            elseif islogical(v); value=mat2str(double(v));
            elseif isnumeric(v); value=mat2str(v);
            else; value=char(v); end
            controls{i}=uicontrol(tab,'Style','edit','String',value,'HorizontalAlignment','left','Position',[395 y 355 28]);
            if strcmp(type,'file')
                uicontrol(tab,'Style','pushbutton','String','Browse','Position',[760 y 85 28], ...
                    'TooltipString',tip, ...
                    'Callback',@(~,~) browse(controls{i},rows{i,2}));
            end
        end
        set(controls{i},'Tag',strrep(rows{i,2},'.','_'),'TooltipString',tip);
        if ischar(type) && strcmp(type,'bool'); set(controls{i},'Callback',@(~,~) refresh()); end
    end
end
uicontrol(dialog,'Style','text','Position',[15 62 870 34],'HorizontalAlignment','left', ...
    'String',sprintf('Doppler/TDCP total switches and thresholds remain in the main window. Reset enabled: %d.\nNew TDCP uses per-frequency decisions; record-only mode does not change ambiguities.',original.PROC.reset_float));
uicontrol(dialog,'Style','pushbutton','String','Apply','Tag','quality_apply','Position',[650 18 105 32],'Callback',@apply);
uicontrol(dialog,'Style','pushbutton','String','Cancel','Position',[765 18 105 32],'Callback',@(~,~) delete(dialog));
setappdata(dialog,'QualityControls',controls);
refresh();
    function refresh()
        enabled=struct('cold',flag('PROC.cold_start.enable'), ...
            'prediction',flag('PROC.predicted_phase.enable'),'raim',flag('PROC.raim.enable'));
        for n=1:size(rows,1)
            key=rows{n,2}; on=true;
            if startsWith(key,'PROC.cold_start.') && ~strcmp(key,'PROC.cold_start.enable'); on=enabled.cold; end
            if startsWith(key,'PROC.predicted_phase.') && ~strcmp(key,'PROC.predicted_phase.enable'); on=enabled.prediction; end
            if startsWith(key,'PROC.raim.') && ~strcmp(key,'PROC.raim.enable'); on=enabled.raim; end
            state='off'; if on; state='on'; end
            set(controls{n},'Enable',state);
        end
    end
    function on=flag(key)
        index=find(strcmp(rows(:,2),key),1); on=logical(get(controls{index},'Value'));
    end
    function browse(control,path)
        if contains(path,'calibration'); filter='*.mat'; else; filter='*.csv'; end
        [file,folder]=uigetfile(filter,'Select input file');
        if ~isequal(file,0); set(control,'String',fullfile(folder,file)); end
    end
    function apply(~,~)
        try
            current=guidata(owner); s=getSettingsFromGUI(current);
            for n=1:size(rows,1)
                type=rows{n,5}; control=controls{n};
                if iscell(type); value=type{get(control,'Value')};
                elseif strcmp(type,'bool'); value=logical(get(control,'Value'));
                elseif strcmp(type,'number'); value=str2double(get(control,'String'));
                elseif strcmp(type,'matrix')
                    input=strtrim(get(control,'String'));
                    if isempty(regexp(input,'^[\[\]01 ;,]+$','once')); error('Use a 0/1 matrix for %s.',rows{n,3}); end
                    parts=strsplit(strrep(strrep(input,'[',''),']',''),';'); value=[];
                    for z=1:numel(parts); value=[value; sscanf(strrep(parts{z},',',' '),'%f')']; end %#ok<AGROW>
                elseif strcmp(type,'signals')
                    input=strtrim(get(control,'String')); value={};
                    if ~isempty(input); value=cellstr(strtrim(split(string(input),',')))'; end
                else; value=strtrim(get(control,'String')); end
                s=qualityControlField(s,rows{n,2},value);
            end
            problems=validateQualityControlSettings(s,true);
            if ~isempty(problems); error('QualityControl:Settings','%s',strjoin(problems,newline)); end
            current.quality_control=copyQualityControlSettings(struct(),s);
            guidata(owner,current); delete(dialog);
        catch ex; errordlg(ex.message,'Quality control settings','modal'); end
    end
end
