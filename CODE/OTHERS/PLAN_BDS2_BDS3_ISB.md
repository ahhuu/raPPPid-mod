# BDS-2/BDS-3 固定 ISB 改正实施计划

## 1. 目标与结论先行

本计划目标：在现有 `estimate_bds23_isb`（free / constrained）基础上，新增 **固定 ISB 改正（fixed correction）** 方法，用于短时段（如 20 分钟 / 1200 历元）与 BDS-2 可观测性不足场景，降低高度退化风险。

核心原则：
1. **不新增自由状态参数**（与“估计 ISB”不同）
2. **只做观测模型常数改正**（BDS-3 组应用固定偏置）
3. **默认向后兼容**（旧设置不受影响）
4. **与现有 GUI 与 settings 链路保持一致**

---

## 2. 适用场景与非目标

### 2.1 适用场景

- 智能手机 PPP 短弧段（约 10–30 分钟）
- BDS-2 平均有效卫星偏少（如 < 4）
- `free` / `constrained` 仍显著劣于“关闭 ISB”基线

### 2.2 非目标

- 本阶段不做“自动模式切换”闭环控制（可作为下一阶段）
- 不重构 DCM 全链路（仅在当前 ZD 主链落地）
- 不引入新的多频/信号跟踪偏差复杂建模

---

## 3. 方法定义（固定 ISB 改正）

## 3.1 数学形式

保留当前公共 BDS 钟差参数化：

- BDS-2：
\[
\rho_{B2}=\cdots + c\,dt_{BDS\_common} + \varepsilon
\]

- BDS-3（固定改正）：
\[
\rho_{B3}=\cdots + c\,dt_{BDS\_common} + c\,\Delta_{B3\leftarrow B2}^{fixed} + \varepsilon
\]

其中 \(\Delta_{B3\leftarrow B2}^{fixed}\) 为固定常数（单位 m），来自标定结果或手工配置。

### 3.2 与现有模式关系

- `off`：不分离，不改正
- `free`：每历元估计 ISB 状态
- `constrained`：估计 ISB + 先验约束
- **`fixed`（新增）**：不估计 ISB，只对 BDS-3 施加固定改正

---

## 4. 设置设计（单点真源）

在 `settings.BIASES` 增加/规范以下字段：

- `estimate_bds23_isb`（logical，已有）
- `bds23_isb_mode`（string）：`'off' | 'free' | 'constrained' | 'fixed'`
- `bds23_isb_prior_m`（double，已有，constrained 用）
- `bds23_isb_prior_sigma_m`（double，已有，constrained 用）
- **`bds23_isb_fixed_m`（double，新增，fixed 用）**

默认值策略：
- 旧版本加载时，若缺字段：
  - `bds23_isb_mode='free'`（保持现行为主）
  - `bds23_isb_fixed_m=0.0`

兼容策略：
- 当 `estimate_bds23_isb=false` 时，`bds23_isb_mode` 可忽略（视为 off）
- 当 `mode='fixed'` 且 `fixed_m` 为空/NaN，自动回退到 0 并告警

---

## 5. GUI 与设置链改造计划

## 5.1 GUI_PPP（展示与交互）

改造点：
1. 在现有 BDS-2/3 ISB 模式下拉中加入 `fixed`
2. 当模式为 `fixed`：
   - 显示 `Fixed[m]` 输入框
   - 隐藏 `Prior[m]`、`Sigma[m]`
3. 当模式为 `constrained`：
   - 显示 `Prior[m]`、`Sigma[m]`
4. 当模式为 `free`：
   - 三个输入框均隐藏

交互规则：
- 切换模式仅改 UI 可见性，不自动改值
- 关闭主开关时，所有相关输入框禁用/隐藏

## 5.2 getSettingsFromGUI

新增读取：
- `settings.BIASES.bds23_isb_fixed_m`

补充容错：
- 空字符串、非数字输入转换为 `0` 并给出一次性提示

## 5.3 setSettingsToGUI

新增回填：
- `bds23_isb_mode='fixed'` 时回填 `edit_bds23_isb_fixed`

## 5.4 checkProcessingSettings

新增校验逻辑：
1. `mode='fixed'` 时必须是有限实数
2. 若 `use_BDS=false`，统一禁用 BDS23 ISB 功能
3. 若 DCM 路径不支持，提示并降级（与现有策略一致）

---

## 6. 处理链改造计划（ZD 主链）

## 6.1 设计原则

- `fixed` 模式下 **不增加参数维度**
- 不触发 `param(20)` 估计链
- 仅在观测模型处对 BDS-3 施加常量修正

## 6.2 具体文件与动作

1. `CODE/PROCESSING/initProcessing.m`
- `mode='fixed'` 时维持 `Adjust.NO_PARAM` 与“未估计 ISB”一致（19）

2. `CODE/PROCESSING/adjustmentPreparation_ZD.m`
- `fixed` 模式不初始化 ISB 状态，不扩展协方差/噪声/转移矩阵

3. `CODE/PROCESSING/Designmatrix_ZD.m`
- `fixed` 模式不新增 ISB 列（保持原 BDS 公共钟差列）

4. `CODE/PROCESSING/Designmatrix_code_ZD.m`
- 同上，纯码链保持无 ISB 新状态

5. `CODE/PROCESSING/modelErrorSources.m`
- 在 BDS-3 观测项中施加固定改正（符号与单位统一）
- 建议实现为：
  - 先构建 `isb_fix = settings.BIASES.bds23_isb_fixed_m`
  - 若卫星属于 BDS-3，则在模型项中加/减 `isb_fix`（以残差定义为准）

6. `CODE/PROCESSING/modelApproximately.m`（若该链路参与同一残差定义）
- 与 `modelErrorSources.m` 保持一致的改正符号

7. `CODE/PROCESSING/getReceiverClockBiases.m`
- `fixed` 模式下不输出“估计的 ISB 参数”，但可在日志注明“应用固定 ISB 改正”

8. `CODE/PROCESSING/settings2txt.m`
- 输出：
  - `BDS-2/3 ISB mode: fixed`
  - `BDS-3 fixed ISB correction [m]: xxx`

---

## 7. 标定与使用流程计划

## 7.1 标定来源

沿用 `calibrate_bds23_isb.m` 的统计结果，建议新增输出字段：
- `recommended_fixed_m`
- `recommended_sigma_m`（仅供 constrained 参考）

## 7.2 操作流程（固定改正）

1. 用较好数据做一次标定（或取历史稳定中位数）
2. 在 GUI 选择 `fixed`
3. 填入 `Fixed[m]`
4. 运行 20 分钟短弧段数据
5. 对比 `off / constrained / fixed` 的 dH RMS 与收敛稳定性

---

## 8. 输出与诊断增强计划

在现有统计基础上补 3 条轻量输出（不增加冗余）：

1. 当前模式：`off/free/constrained/fixed`
2. 若 `fixed`：打印固定值（m 与 ns）
3. 处理后打印 BDS-2/BDS-3 组残差中位差（用于 sanity check）

目标：快速判断“固定改正是否方向正确、量级合理”。

---

## 9. 测试与验收计划

## 9.1 最小测试矩阵

同一数据集至少跑 4 组：
1. `off`
2. `free`
3. `constrained`
4. `fixed`

记录指标：
- dH/dN/dE RMS
- 前 300 历元后稳定段 RMS
- BDS-2/BDS-3 有效星均值
- 组间残差中位差

## 9.2 验收准则（建议）

- `fixed` 相比 `constrained`：
  - dH RMS 不劣于其 95%（即至少持平或更优）
- `fixed` 相比 `off`：
  - 若未达到改进，允许保留但默认策略仍可选 `off`
- 不引入新报错、不改变旧配置行为

## 9.3 回归检查

- 旧 `settings.mat` 可正常加载
- 不启用 BDS23 功能时结果应与改造前一致（数值级一致或仅浮点末位差）

---

## 10. 风险与应对

风险 1：固定值符号用反，导致结果恶化
- 应对：在日志中同时打印 m 和 ns，并用短样本做正负号 A/B 检查

风险 2：固定值跨天漂移
- 应对：建议按设备/频点/温度条件维护固定值库；必要时定期重标定

风险 3：与 constrained 逻辑冲突
- 应对：三种模式互斥分支，统一由 `bds23_isb_mode` 控制

---

## 11. 实施里程碑

M1（设置与 GUI）
- 增加 `fixed` 模式与 `fixed_m` 字段
- GUI 显示逻辑打通

M2（处理链）
- 完成 ZD 主链固定改正注入
- 保证 `fixed` 不引入新状态参数

M3（诊断与导出）
- `settings2txt` 与终端统计补充 fixed 信息

M4（验证与文档）
- 完成 4 组对比测试
- 在 BDS23 README 增加 fixed 模式说明

---

## 12. 交付清单

代码改造文件（计划）：
- `CODE/VISUAL/GUI/GUI_PPP.m`
- `CODE/READ/getSettingsFromGUI.m`
- `CODE/VISUAL/GUI/setSettingsToGUI.m`
- `CODE/READ/checkProcessingSettings.m`
- `CODE/PROCESSING/initProcessing.m`
- `CODE/PROCESSING/adjustmentPreparation_ZD.m`
- `CODE/PROCESSING/Designmatrix_ZD.m`
- `CODE/PROCESSING/Designmatrix_code_ZD.m`
- `CODE/PROCESSING/modelErrorSources.m`
- `CODE/PROCESSING/modelApproximately.m`（如需）
- `CODE/PROCESSING/settings2txt.m`
- `CODE/OTHERS/calibrate_bds23_isb.m`（建议增强）
- `CODE/OTHERS/BDS23_ISB_README.md`（文档同步）

---

## 13. 下一步执行建议

按“最小可用改造”先落地：
1. 仅实现 `fixed` 模式 + `modelErrorSources.m` 注入 + `settings2txt` 输出
2. 先不改自动切换策略
3. 先用你当前 20 分钟数据做四模式 A/B
4. 若 `fixed` 稳定优于 `constrained`，再推进自动策略阶段
