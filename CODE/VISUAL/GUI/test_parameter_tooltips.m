function test_parameter_tooltips()
% Check every parameter, including disabled/hidden controls and tables.
f=GUI_PPP('Visible','off'); cleanup=onCleanup(@() delete(f)); %#ok<NASGU>
count=check(f);
d=GUI_QualityControl(f); dialog_cleanup=onCleanup(@() delete(d)); %#ok<NASGU>
advanced=check(d);
schema=qualityControlSchema();
for k=1:size(schema,1)
    tip=qualityControlTooltip(schema{k,2});
    assert(~strcmp(tip,schema{k,3}) && numel(tip)>15);
end
fprintf('PARAMETER_TOOLTIPS_PASS main=%d advanced=%d\n',count,advanced);
end
function count=check(f)
controls=findall(f,'Type','uicontrol'); count=0;
for k=1:numel(controls)
    if ~ismember(get(controls(k),'Style'),{'edit','checkbox','radiobutton','popupmenu','listbox','slider','togglebutton'}); continue; end
    assert(~isempty(strtrim(get(controls(k),'TooltipString'))),'Missing tooltip: %s',get(controls(k),'Tag'));
    count=count+1;
end
tables=findall(f,'Type','uitable');
for k=1:numel(tables)
    if isprop(tables(k),'TooltipString'); tip=get(tables(k),'TooltipString');
    else; tip=get(tables(k),'Tooltip'); end
    assert(~isempty(strtrim(tip)),'Missing table tooltip: %s',get(tables(k),'Tag'));
    count=count+1;
end
end
