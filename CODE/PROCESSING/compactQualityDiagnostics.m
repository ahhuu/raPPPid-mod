function storeData = compactQualityDiagnostics(storeData)
% Export-only reduction. Keep legacy fields and scalar epoch diagnostics.
names=fieldnames(storeData);
remove=endsWith(names,'_freq') & (startsWith(names,'phase_prediction') | ...
    startsWith(names,'phase_predicted') | startsWith(names,'raim_') | ...
    strcmp(names,'exclude_freq') | strcmp(names,'cs_found_freq'));
storeData=rmfield(storeData,names(remove));
end
