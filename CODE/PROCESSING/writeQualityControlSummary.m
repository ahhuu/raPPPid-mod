function writeQualityControlSummary(fileID,settings)
settings=applyQualityControlDefaults(settings); rows=qualityControlSchema();
fprintf(fileID,'\nAdvanced quality-control configuration (frequency slots follow selected signals):\n');
for k=1:size(rows,1)
    [~,v]=qualityControlField(settings,rows{k,2});
    if isnumeric(v)||islogical(v); value=mat2str(v);
    elseif iscell(v); value=strjoin(v,','); else; value=char(v); end
    fprintf(fileID,'  %s = %s\n',rows{k,2},value);
end
end
