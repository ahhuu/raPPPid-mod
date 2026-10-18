function [s, value, found] = qualityControlField(s, path, varargin)
% Read/write a dotted structure field without eval.
names = strsplit(path,'.');
[s,value,found] = visit(s,names,varargin);
end
function [s,value,found] = visit(s,names,args)
name=names{1}; value=[]; found=false;
if isempty(args)
    if ~isstruct(s) || ~isfield(s,name); return; end
    if numel(names)==1; value=s.(name); found=true;
    else; [~,value,found]=visit(s.(name),names(2:end),args); end
else
    if numel(names)==1; s.(name)=args{1}; value=args{1}; found=true;
    else
        if ~isfield(s,name) || ~isstruct(s.(name)); s.(name)=struct(); end
        [s.(name),value,found]=visit(s.(name),names(2:end),args);
    end
end
end
