function summarizeRaimEvidence20261005(report_file)
%SUMMARIZERAIMEVIDENCE20261005 Generate an evidence-linked readable summary.
S=load(report_file,'report'); report=S.report; folder=fileparts(report_file);
fid=fopen(fullfile(folder,'RAIM_stage3_summary.txt'),'w','n','UTF-8');
assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'三手机树荫 PPP：RAIM 第三阶段验证（2026-10-05）\n\n');
fprintf(fid,'数据清单：%s\n',report.manifest_file);
fprintf(fid,['三机全量重跑，按 11 历元间隔捕获矩阵。前半时段标定、后半时段验证，中间留出 60 秒。\n' ...
    'WLS 条件于当前电离层估计；未提供航空完整性或保护水平保证。\n' ...
    '以下报警比例不是虚警率：树荫真实观测没有逐条无故障标签。\n' ...
    '多个注入试验共享历元，不能当作完全独立样本推断置信区间。\n\n']);
devices={'K80','X6','ACE5'}; colors=lines(3);
fig=figure('Visible','off','Position',[100 100 1200 500]);
finish=onCleanup(@() close(fig)); %#ok<NASGU>
tiledlayout(1,2,'TileSpacing','compact');
ax1=nexttile; hold(ax1,'on'); ax2=nexttile; hold(ax2,'on');
for k=1:3
    device=devices{k};
    row=report.summary(strcmp(report.summary.device,device) & ...
        strcmp(report.summary.variant,'empirical_grouped'),:);
    I=report.injection(strcmp(report.injection.device,device) & ...
        strcmp(report.injection.variant,'empirical_grouped'),:);
    real=I(strcmp(I.data_kind,'real_shaded') & I.fault_m>0,:);
    gaussian=I(strcmp(I.data_kind,'matched_gaussian'),:);
    fprintf(fid,'%s：训练 %d 历元，留出验证 %d 历元，标定后报警 %.2f%%。\n', ...
        device,row.train_epochs,row.validation_epochs,row.real_alarm_pct);
    for j=1:height(real)
        fprintf(fid,'  正负 %g m，%d 次试验：报警 %.2f%%，正确定位且报警 %.2f%%。\n', ...
            real.fault_m(j),real.trials(j),real.alarm_pct(j), ...
            real.correct_localization_and_alarm_pct(j));
    end
    g=gaussian(gaussian.fault_m==0,:);
    fprintf(fid,'  匹配几何/假设协方差的无故障高斯试验：%d 次，虚警 %.3f%%（目标 0.1%%）。\n', ...
        g.trials,g.alarm_pct);
    F=report.shadow(strcmp(report.shadow.device,device) & ...
        strcmp(report.shadow.variant,'empirical_grouped'),:);
    for amplitude=[0 10 40]
        mask=abs(F.fault_m)==amplitude;
        accepted=sum(F.accepted(mask)); correct=sum(F.correct_injected_row(mask)==1);
        fprintf(fid,'  离线排除复检 |注入|=%g m：%d 试验，%d 建议通过；',amplitude,sum(mask),accepted);
        if amplitude==0
            fprintf(fid,'原始故障未知，不能判定建议是否正确。\n');
        else
            fprintf(fid,'%d 次通过且选中注入观测，%d 次通过但选中其他观测。\n',correct,accepted-correct);
        end
    end
    fprintf(fid,'\n');
    plot(ax1,real.fault_m,real.correct_localization_and_alarm_pct,'-o', ...
        'Color',colors(k,:),'LineWidth',1.7,'DisplayName',device);
    g=gaussian(gaussian.fault_m>0,:);
    plot(ax2,g.fault_m,g.correct_localization_and_alarm_pct,'-o', ...
        'Color',colors(k,:),'LineWidth',1.7,'DisplayName',device);
end
for ax=[ax1 ax2]
    grid(ax,'on'); ylim(ax,[0 100]); xticks(ax,[5 10 20 40]);
    xlabel(ax,'Injected single-observation fault |m|');
    ylabel(ax,'Global alarm AND correct row (%)'); legend(ax,'Location','northwest');
end
title(ax1,'Held-out real shaded data + injected fault');
title(ax2,'Matched Gaussian noise + injected fault');
sgtitle('RAIM sensitivity after chronological grouped calibration');
exportgraphics(fig,fullfile(folder,'fault_localization.png'),'Resolution',140);
audit=report.innovation;
fprintf(fid,'创新检验：共 %d 个采样历元，%d 个协方差条件数不足，已明确标记不可用。\n', ...
    height(audit),sum(strcmp(audit.status,'ill_conditioned_covariance')));
fprintf(fid,['高相关噪声下，边际标准化量小并不表示整体检验错误。当前使用条件得分及同一预测点。\n' ...
    '单观测排除仅离线提出建议，未反馈给 PPP。小粗差定位能力不足，不能默认自动剔除。\n' ...
    '本轮没有定位精度提升结论；监测开关 60 历元对照见上级目录 monitor_compatibility.csv。\n']);
fprintf('SUMMARY %s\n',fullfile(folder,'RAIM_stage3_summary.txt'));
end
