function corr_ = Convert2ProcFrqs(settings, j, corr, f1, f2, f3, corr_)
% This function converts a specific correction from the raw frequencies to
% the processed frequency, for example, of the ionosphere-free linear
% combination.
%
% INPUT:
%   settings        struct, processing settings from GUI
%   j               indices of processed frequencies
%   corr            correction on the raw frequencies
%   f1, f2, f3      raw signal frequencies
%   corr_           initialized vector
% OUTPUT:
%	corr_           correction converted to the processed signal frequency
%
% Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2025, M.F. Wareyka-Glaner
% *************************************************************************


switch settings.IONO.model

    case '2-Frequency-IF-LCs'
        corr_(1) = (f1^2*corr(j(1))-f2^2*corr(j(2))) / (f1^2-f2^2);
        if settings.INPUT.proc_freqs == 2
            corr_(2) = (f2^2*corr(j(2))-f3^2*corr(j(3))) / (f2^2-f3^2);
        end

    case '3-Frequency-IF-LC'
        y2 = f1.^2 ./ f2.^2;            % coefficients of 3-Frequency-IF-LC
        y3 = f1.^2 ./ f3.^2;
        e1 = (y2.^2 +y3.^2  -y2-y3) ./ (2.*(y2.^2 +y3.^2 -y2.*y3 -y2-y3+1));
        e2 = (y3.^2 -y2.*y3 -y2 +1) ./ (2.*(y2.^2 +y3.^2 -y2.*y3 -y2-y3+1));
        e3 = (y2.^2 -y2.*y3 -y3 +1) ./ (2.*(y2.^2 +y3.^2 -y2.*y3 -y2-y3+1));
        corr_(1) = e1.*corr(j(1)) + e2.*corr(j(2)) + e3.*corr(j(3));

    otherwise        % uncombined signals are processed (no linear combination)
        corr_(1:numel(j)) = corr(j);
        
end