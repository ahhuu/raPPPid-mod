function text = qualityControlTooltip(key)
% User-facing explanations for every field in qualityControlSchema.
rows={
'OTHER.CS.D_robust','启用稳健多普勒积分，降低异常 Doppler 对周跳判定的影响；还需在主窗口开启 Doppler-Shift。';
'OTHER.CS.D_mad_factor','稳健多普勒筛选的 MAD 倍数（正数）；较大值保留更多样本，仅在稳健模式开启时生效。';
'OTHER.CS.D_freq_enable','1×3 的 0/1 向量，例如 [1 1 0]。按配置频率槽启用 Doppler 检测，不代表固定物理频段。';
'OTHER.CS.D_system_freq_enable','5×3 的 0/1 矩阵；行依次为 GPS/GLO/GAL/BDS/QZSS，列为频率槽 1/2/3。分号分行，与频率掩码共同生效。';
'OTHER.CS.TDCP_log_only','只记录 TDCP 检测结果，不因 TDCP 判定重置模糊度；其他检测器仍可触发周跳处理。需开启主窗口 TDCP。';
'OTHER.CS.TDCP_z_factor','TDCP 自适应残差门限的 MAD 倍数（正数）；与主窗口基础残差门限共同作用，较小值更敏感。';
'OTHER.CS.TDCP_min_sats','TDCP 拟合所需最少卫星数（整数，至少 6）；不足时不能可靠执行该检测。';
'OTHER.CS.TDCP_max_reject','每个频率允许迭代剔除的最多卫星数（非负整数）；避免无限制剔除。';
'PROC.cold_start.enable','在初始化/重置后使用多历元码相位窗口启动；需 Code + Phase 且开启相位对齐或接收机钟跳补偿。默认关闭。';
'PROC.cold_start.window_epochs','冷启动窗口长度（历元，正整数）；不是秒。仅在冷启动开启时生效。';
'PROC.cold_start.min_samples','窗口中每个初始化所需的最少有效样本数（正整数），不能超过窗口长度。';
'PROC.cold_start.robust_code','在冷启动窗口内，基于码与 Doppler 创新对异常码观测稳健降权；需开启冷启动。';
'PROC.cold_start.huber_c','Huber 降权倍数（正数）；越小通常对异常码观测降权越强。';
'PROC.cold_start.scale_floor_m','稳健尺度下限（m，正数），避免估计尺度过小导致过度降权。';
'PROC.cold_start.weight_floor','稳健码权重下限（0 到 1 之间的正数）；越小允许的最大降权越强。';
'PROC.predicted_phase.enable','读取已写入输入 RINEX 的预测相位对应元数据并应用质量控制；本开关不会生成预测相位。默认关闭。';
'PROC.predicted_phase.metadata_file','选择与当前 RINEX 时段匹配的预测元数据 CSV，包含时间、卫星、信号、预测长度、sigma 和 accepted 等字段。';
'PROC.predicted_phase.max_prediction_length','允许使用的最大预测长度（历元）；超过此长度的预测相位不被接受，Inf 不设长度上限。';
'PROC.predicted_phase.sigma_scale','元数据 sigma 的正比例因子；越大表示预测相位不确定度越大、权重越低。';
'PROC.predicted_phase.sigma_floor_m','预测相位标准差下限（m，正数），防止权重过高。';
'PROC.predicted_phase.time_tolerance_ms','预测元数据与观测匹配的时间容差（ms，0–1000 的整数）；过大可能误配附近历元。';
'PROC.predicted_phase.exclude_from_cycle_slip','预测相位不参与非 LLI 周跳检测，避免人为插值影响检测；RINEX 的 LLI 失锁标志仍保留。';
'PROC.predicted_phase.quality_rms_file','独立预测质量 CSV：satellite、frequency、prediction_length、sample_count、rms_m。应与所用设备/信号质量评估匹配。';
'PROC.predicted_phase.quality_max_rms_m','允许的预测质量 RMS 上限（m）；超过上限拒绝该预测，Inf 不设 RMS 上限。';
'PROC.predicted_phase.quality_sigma_scale','将质量 RMS 转换为相位标准差下限的倍率；越大表示质量评估导致的降权越强。';
'PROC.predicted_phase.quality_min_samples','质量记录所需最少样本数（非负整数）；样本不足的记录不作为合格质量证据。';
'PROC.predicted_phase.reject_if_quality_missing','缺少匹配质量记录时拒绝预测相位；默认开启。关闭表示允许无质量证据的预测通过此项检查。';
'PROC.predicted_phase.allowed_signals','允许信号列表，用逗号分隔，例如 G:L1C,C:L2I；留空允许全部已选信号，其他质量门限仍有效。';
'PROC.raim.enable','启用码观测一致性监测；action=none 只记录结果。属于实验性诊断，不提供完整 HPL/VPL 完好性保证。';
'PROC.raim.test_model','wls_residual：WLS 残差检验；innovation：创新检验。当前排除/降权动作仅支持兼容的 WLS 模型。';
'PROC.raim.pfa_global','全局检验的名义虚警概率（0 到 1 之间）；阈值还依赖模型和标定，不能直接视为实测误报率。';
'PROC.raim.min_redundancy','执行检验所需的最小冗余度（正整数）；不足时跳过检验。';
'PROC.raim.capture_stride','每隔多少历元保存一次回放诊断（非负整数）；0 关闭捕获，较小值增加存储量。';
'PROC.raim.experiment_action','none：只监测；exclude_code：实验性排除码观测；downweight_code：实验性增大码方差。后两者需冻结标定及时间范围。';
'PROC.raim.calibration_file','冻结标定 MAT，包含 model.global_scale、model.keys、model.scales；必须适配设备和观测模型，GUI 不自动拟合标定。';
'PROC.raim.validation_gps_week','允许动作生效的 GPS 周（整数）；不同周不应用动作。启用排除/降权时必须填写，避免跨周误用标定。';
'PROC.raim.validation_start_sow','允许动作开始的 GPS 周内秒（0≤值<604800）；不是当天秒数。启用动作时必须填写。';
'PROC.raim.downweight_variance_factor','downweight_code 使用的码方差倍数（≥1）；例如 25 对应标准差放大 5 倍，仅影响命中的码观测。';
'EXP.quality_diagnostics','在 data4plot.mat 保存逐频周跳、排除及质量诊断数组；关闭可减少导出体积，不改变解算或主结果数组。';
};
index=find(strcmp(rows(:,1),key),1);
assert(~isempty(index),'Missing quality-control tooltip: %s',key);
text=rows{index,2};
end
