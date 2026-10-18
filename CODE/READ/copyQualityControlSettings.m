function destination = copyQualityControlSettings(destination, source)
% Explicit allow-list: do not inherit arbitrary experiment switches.
source=applyQualityControlDefaults(source);
rows=qualityControlSchema();
for k=1:size(rows,1)
    [~,value]=qualityControlField(source,rows{k,2});
    destination=qualityControlField(destination,rows{k,2},value);
end
destination=applyQualityControlDefaults(destination);
end
