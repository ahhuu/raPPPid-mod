function [settings] = DownloadStreamArchive(settings, gpsweek, dow, yyyy, mm, doy)
% This function dowloads the selected archived stream and manipulates
% settings that the processings works with the file-formats
%
% INPUT:
%	settings        struct, settings from GUI
%   gpsweek         string, GPS Week
%   dow             string, 1-digit, day of week
%   yyyy            string, 4-digit, year
%   mm              string, 2-digit, month
%   doy             string, 3-digit, day of year
% OUTPUT:
%	settings        updated and manipulated for correct processing
%
% Revision:
%   ...
%
% This function belongs to raPPPid, Copyright (c) 2023, M.F. Glaner
% *************************************************************************



target = [Path.DATA, 'STREAM/', yyyy, '/', doy '/'];
[~, ~] = mkdir(target);

    switch settings.ORBCLK.CorrectionStream
        case 'CNES Archive'
            file_sp3 = ['cnt' gpsweek dow '.sp3'];
            file_clk = ['cnt' gpsweek dow '.clk'];
            file_bia = ['cnt' gpsweek dow '.bia'];
            file_obx = ['cnt' gpsweek dow '.obx'];      % since 2054/2
            targets = repmat({target},4,1);
            
            % 下载 orbit 文件
            if ~( exist([target file_sp3],'file') || exist([target file_sp3 '.mat'],'file') )
                try
                    websave([target file_sp3 '.gz'] , ['http://www.ppp-wizard.net/products/REAL_TIME/' file_sp3 '.gz']);
                    fprintf('Successfully downloaded %s\n', [target file_sp3 '.gz']);
                catch ME
                    fprintf('Failed to download %s: %s\n', [target file_sp3 '.gz'], ME.message);
                end
            end
            
            % 下载 clock 文件
            if ~( exist([target file_clk],'file') || exist([target file_clk '.mat'],'file') )
                try
                    websave([target file_clk '.gz'] , ['http://www.ppp-wizard.net/products/REAL_TIME/' file_clk '.gz']);
                    fprintf('Successfully downloaded %s\n', [target file_clk '.gz']);
                catch ME
                    fprintf('Failed to download %s: %s\n', [target file_clk '.gz'], ME.message);
                end
            end
            
            % 下载 bias 文件
            if ~( exist([target file_bia],'file') || exist([target file_bia '.mat'],'file') )
                try
                    websave([target file_bia '.gz'] , ['http://www.ppp-wizard.net/products/REAL_TIME/' file_bia '.gz']);
                    fprintf('Successfully downloaded %s\n', [target file_bia '.gz']);
                catch ME
                    fprintf('Failed to download %s: %s\n', [target file_bia '.gz'], ME.message);
                end
            end
            
            % 下载 obx 文件
            if ~( exist([target file_obx],'file'))
                try
                    websave([target file_obx '.gz'] , ['http://www.ppp-wizard.net/products/REAL_TIME/' file_obx '.gz']);
                    fprintf('Successfully downloaded %s\n', [target file_obx '.gz']);
                catch ME
                    fprintf('Failed to download %s: %s\n', [target file_obx '.gz'], ME.message);
                end
            end
            
            files = {[file_sp3 '.gz']
                     [file_clk '.gz']
                     [file_bia '.gz']
                     [file_obx '.gz']};
            unzip_and_delete(files, targets);     % much faster than gunzip
            % orbit and clock handling like with "Precise Products" (sp3 and clk-file)
            settings.ORBCLK.file_sp3 = [target file_sp3];
            settings.ORBCLK.file_clk = [target file_clk];
            settings.ORBCLK.file_obx = [target file_obx];
            % use .bia-file
            settings.BIASES.code_file  = [target file_bia];
            settings.BIASES.phase_file = [target file_bia];
            
        case 'IGC01 Archive'
            targets = {target; target};
            host = 'https://cddis.nasa.gov';
            folders = repmat({['/archive/gnss/products/rtpp/' gpsweek]},2,1);
            files = {['igc' gpsweek dow '.sp3.Z'];
                     ['igc' gpsweek dow '.clk.Z']};
            filestatus = get_cddis_data(host, folders, files, targets, true);
            if any(filestatus==0)
                errordlg(['No correction stream from ' settings.ORBCLK.CorrectionStream ' found on server. Please specify different source!'], 'Error');
            end
            % decompress
            for i = 1:2
                if filestatus(i) == 1   ||   filestatus(i) == 2
                    unzip_and_delete(files(i), targets(i));
                end
                [~,files{i},~] = fileparts(files{i});   % remove the zip file extension
            end 
            % orbit and clock handling like with "Precise Products" (sp3 and clk-file)
            settings.ORBCLK.file_sp3 = [targets{1} '/' files{1}];
            settings.ORBCLK.file_clk = [targets{2} '/' files{2}];
            
        case 'CAS Archive'
            % from the data center of the Chinese Academy of Sciences (CAS)
            httpserver = ['https://data.bdsmart.cn/pub/product/rts/rtpp/' yyyy];        
            
            % 尝试新的1分钟间隔格式，如果失败则回退到5分钟间隔格式
            file_sp3_1m  = ['CAS0MGXRTS_' yyyy doy '0000_01D_01M_ORB.SP3.gz'];
            dcmpr_sp3_1m = ['CAS0MGXRTS_' yyyy doy '0000_01D_01M_ORB.SP3'];
            file_sp3_5m  = ['CAS0MGXRTS_' yyyy doy '0000_01D_05M_ORB.SP3.gz'];
            dcmpr_sp3_5m = ['CAS0MGXRTS_' yyyy doy '0000_01D_05M_ORB.SP3'];
            
            file_clk  = ['CAS0MGXRTS_' yyyy doy '0000_01D_30S_CLK.CLK.gz'];
            dcmpr_clk = ['CAS0MGXRTS_' yyyy doy '0000_01D_30S_CLK.CLK'];
            
            % 首先尝试1分钟间隔的轨道文件
            file_sp3 = file_sp3_1m;
            dcmpr_sp3 = dcmpr_sp3_1m;
            file_format = '01M';
            
            % try to download
            if ~isfile([target file_sp3]) && ~isfile([target dcmpr_sp3])
                % 检查本地是否有1分钟格式文件
                if exist([target file_sp3_1m], 'file')
                    fprintf('Using existing local file: %s\n', [target file_sp3_1m]);
                    file_sp3 = file_sp3_1m;
                    dcmpr_sp3 = dcmpr_sp3_1m;
                    file_format = '01M';
                elseif exist([target file_sp3_5m], 'file')
                    fprintf('Using existing local file: %s\n', [target file_sp3_5m]);
                    file_sp3 = file_sp3_5m;
                    dcmpr_sp3 = dcmpr_sp3_5m;
                    file_format = '05M';
                else
                    try
                        websave([target file_sp3], [httpserver '/' file_sp3]);
                        fprintf('Successfully downloaded %s\n', [target file_sp3]);
                    catch ME
                        fprintf('Failed to download %s: %s\n', [target file_sp3], ME.message);
                        % 如果1分钟格式失败，尝试5分钟格式
                        fprintf('Trying fallback to 5-minute format...\n');
                        file_sp3 = file_sp3_5m;
                        dcmpr_sp3 = dcmpr_sp3_5m;
                        file_format = '05M';
                        try
                            websave([target file_sp3], [httpserver '/' file_sp3]);
                            fprintf('Successfully downloaded %s (fallback)\n', [target file_sp3]);
                        catch ME2
                            fprintf('Failed to download %s: %s\n', [target file_sp3], ME2.message);
                            % 检查是否有本地文件作为回退
                            if exist([target file_sp3], 'file')
                                fprintf('Using existing local file as fallback: %s\n', [target file_sp3]);
                            else
                                fprintf('Warning: No CAS orbit file available (tried both 1M and 5M formats)\n');
                            end
                        end
                    end
                end
            end           
            if ~isfile([target file_clk]) && ~isfile([target dcmpr_clk]) && ~isfile([target dcmpr_clk '.mat'])
                if exist([target file_clk], 'file')
                    fprintf('Using existing local file: %s\n', [target file_clk]);
                else
                    try
                        websave([target file_clk], [httpserver '/' file_clk]);
                        fprintf('Successfully downloaded %s\n', [target file_clk]);
                    catch ME
                        fprintf('Failed to download %s: %s\n', [target file_clk], ME.message);
                        % 检查是否有本地文件作为回退
                        if exist([target file_clk], 'file')
                            fprintf('Using existing local file as fallback: %s\n', [target file_clk]);
                        else
                            fprintf('Warning: No CAS clock file available\n');
                        end
                    end
                end
            end
            % unzip if download was successful
            sp3_file_path = unzip_and_delete({file_sp3}, {target});
            clk_file_path = unzip_and_delete({file_clk}, {target});
            
            % 显示使用的文件格式信息
            fprintf('CAS Archive: Using %s format for orbit data\n', file_format);
            
            if ~isfile(sp3_file_path)
                errordlg({'No CAS real-time orbits found in archive.', 'Please do not use!'}, 'Error');
            end
            if ~isfile(clk_file_path) && ~isfile([clk_file_path{1} '.mat'])
                errordlg({'No CAS real-time clocks found in archive.', 'Please do not use!'}, 'Error');
            end
            % orbit and clock handling like with "Precise Products" (sp3 and clk-file)
            settings.ORBCLK.file_sp3 = sp3_file_path{1};
            settings.ORBCLK.file_clk = clk_file_path{1};
    end

% orbit and clock handling like with "Precise Products": sp3, clk
% (in case of CNES Archive the obx file is used depending on
% handles.checkbox_obx.Value)
settings.ORBCLK.bool_sp3 = true;
settings.ORBCLK.bool_clk = true;
settings.ORBCLK.bool_brdc = false;
settings.ORBCLK.bool_nav_multi = false;
settings.ORBCLK.bool_nav_single = false;
settings.ORBCLK.corr2brdc_clk = false;
settings.ORBCLK.corr2brdc_orb = false;
settings.ORBCLK.file_corr2brdc = [];
% information for user that no navigation message is used
if ~settings.INPUT.bool_parfor
    fprintf('\nCorrection stream archive (*.sp3, *.clk,...): No broadcast navigation message is used\n');
end