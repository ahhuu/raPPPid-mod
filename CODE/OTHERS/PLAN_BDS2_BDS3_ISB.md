# BDS-2/BDS-3 分别估计 ISB 功能方案计划

## 1. 背景与动机

### 1.1 论文核心结论（晁文月 et al.）

论文《智能手机北斗2/3系统间偏差分析及其对单点定位的影响》通过零基线双差实验，对华为 P40、小米 8、u-blox F9P 和 Septentrio 四种接收机的 BDS-2/BDS-3 系统间偏差（ISB）进行了分析，得出以下关键结论：

| 接收机 | BDS-2/3 ISB 均值 | ISB 方差 | 考虑ISB后水平精度提升 |
|--------|-------------------|----------|----------------------|
| 华为 P40 | 1.37 m | 1.09 m | 51%（单BDS）/ 57%（多系统） |
| 小米 8 | 1.12 m | 1.17 m | 37%（单BDS）/ 51%（多系统） |
| u-blox F9P | 0.08 m | 0.07 m | ~1% |
| Septentrio | 0.03 m | 0.03 m | ~1% |

**核心发现**：
- 智能手机的 BDS-2/BDS-3 ISB 可达 **1m 以上**，不可忽略
- 专业接收机的 ISB 很小（<0.1m），可视 BDS-2/3 为同一系统
- 智能手机端考虑 BDS-2/BDS-3 ISB 可**显著提升定位精度**（最高 57%）
- ISB 在单天内较稳定，但相邻小时间存在变化（智能手机 STD ~0.3-0.4m）

### 1.2 与 raPPPid 的关联

raPPPid 本身已支持智能手机原始 GNSS 数据处理（通过 `RawSensor2Epoch.m`），且已有 BDS 轨道分层权重功能（区分 GEO/IGSO/MEO）。但当前代码将 **所有 BDS 卫星视为同一系统**，共享一个接收机钟差参数（`param(14)`），无法分别估计 BDS-2 和 BDS-3 的 ISB。

对于智能手机 PPP/SPP 场景，这会导致 m 级的系统偏差被吸收到其他参数中，严重影响定位精度。

---

## 2. 现有代码架构分析

### 2.1 当前参数向量结构（ZD 模式，NO_PARAM_ZD = 19）

| 索引 | 参数 | 说明 |
|------|------|------|
| 1-3 | X, Y, Z | 接收机坐标 |
| 4 | ZWD | 对流层天顶湿延迟 |
| 5 | dt_GPS | GPS 接收机钟差 |
| 6 | DCB_GPS_12 | GPS DCB (频率1-2) |
| 7 | DCB_GPS_13 | GPS DCB (频率1-3) |
| 8 | dt_GLO | GLONASS 时间偏移（ISB） |
| 9 | DCB_GLO_12 | GLONASS DCB |
| 10 | DCB_GLO_13 | GLONASS DCB |
| 11 | dt_GAL | Galileo 时间偏移（ISB） |
| 12 | DCB_GAL_12 | Galileo DCB |
| 13 | DCB_GAL_13 | Galileo DCB |
| 14 | dt_BDS | **BDS 时间偏移（ISB）← 当前 BDS-2/3 共享** |
| 15 | DCB_BDS_12 | BDS DCB |
| 16 | DCB_BDS_13 | BDS DCB |
| 17 | dt_QZSS | QZSS 时间偏移 |
| 18 | DCB_QZSS_12 | QZSS DCB |
| 19 | DCB_QZSS_13 | QZSS DCB |
| 20+ | N_i | 浮点模糊度 |

### 2.2 BDS 卫星编号与识别

- 内部编号：BDS 卫星 PRN = 300 + sv（300-399）
- `Epoch.bds` 逻辑向量标识 BDS 卫星
- 当前无 `Epoch.bds2` / `Epoch.bds3` 区分

### 2.3 BDS-2 vs BDS-3 卫星 PRN 分类（已有参考）

`createWeights.m` 中已有轨道类型区分：
- **BDS-2**: C01-C05 (GEO), C06-C10, C13, C16 (IGSO), C11-C12, C14 (MEO)
- **BDS-3**: C19-C46+ (MEO), C38-C40 (IGSO), C59-C62 (GEO)

可参考 IGS 卫星元数据文件 (`AnalyzeSatelliteMetadataFileIGS.m`) 中的 BDS-2G/BDS-2I/BDS-2M/BDS-3G/BDS-3I/BDS-3M 分类。

### 2.4 关键代码触达点

| 文件 | 涉及逻辑 |
|------|----------|
| `CODE/COMMON/DEF.m` | NO_PARAM_ZD / NO_PARAM_DCM 常量 |
| `CODE/PROCESSING/Designmatrix_ZD.m` | 设计矩阵中 `isBDS` → `param(14)` |
| `CODE/PROCESSING/Designmatrix_code_ZD.m` | 纯码解设计矩阵 |
| `CODE/PROCESSING/Designmatrix_DCM.m` | 解耦钟模型设计矩阵 |
| `CODE/PROCESSING/modelErrorSources.m` | 观测模型中 `isBDS*param(14)` |
| `CODE/PROCESSING/modelApproximately.m` | 近似模型中 `isBDS*param(7/8)` |
| `CODE/PROCESSING/adjustmentPreparation_ZD.m` | 状态向量初始化、噪声/转移矩阵 |
| `CODE/PROCESSING/saveData.m` | 参数存储 |
| `CODE/PROCESSING/RINEX2Epoch.m` | Epoch 构建 |
| `CODE/PROCESSING/RawSensor2Epoch.m` | 智能手机 Epoch 构建 |
| `CODE/READ/getSettingsFromGUI.m` | GUI → settings |
| `CODE/VISUAL/GUI/setSettingsToGUI.m` | settings → GUI |
| `CODE/VISUAL/GUI/GUI_PPP.m` | GUI 回调 |
| `CODE/READ/checkProcessingSettings.m` | 设置校验 |
| `CODE/PROCESSING/settings2txt.m` | 设置导出 |
| `CODE/VISUAL/covParaPlot.m` | 协方差参数绘图 |

---

## 3. 方案设计

### 3.1 设计原则

1. **向后兼容**：不启用该功能时行为完全不变
2. **最小侵入**：通过新增开关控制，不改变已有参数索引含义
3. **参考现有模式**：参照 GLO/GAL/BDS/QZSS ISB 添加方式，增加 BDS-3 ISB 参数
4. **遵循项目规范**：联动 GUI → getSettings → checkSettings → 处理链 → 导出

### 3.2 核心思路

当启用 BDS-2/BDS-3 分别估计 ISB 时：
- **BDS-2 仍使用 `param(14)`**（原 BDS 时间偏移位置）
- **BDS-3 新增一个额外参数** `param(20)` 或在 BDS 参数块后插入，作为 BDS-3 相对于 GPS（或相对于 BDS-2）的时间偏移

**方案选择**：

**方案 A（推荐）：在参数末尾追加 BDS-3 ISB**
- 新增 `NO_PARAM_ZD = 22`（19 → 22，增加 BDS-3 ISB + BDS-3 DCB12 + BDS-3 DCB13）
- `param(14)` 变为仅 BDS-2 时间偏移
- `param(20)` = BDS-3 时间偏移，`param(21)` = BDS-3 DCB12，`param(22)` = BDS-3 DCB13
- 模糊度参数索引向后偏移 3 位

**方案 B（更轻量）：仅增加一个 BDS-3 相对 BDS-2 的 ISB 偏移**
- 新增 `NO_PARAM_ZD = 20`（19 → 20，仅增加 1 个参数）
- `param(14)` 仍为 BDS 时间偏移（BDS-2 使用）
- `param(20)` = BDS-3 相对 BDS-2 的附加 ISB
- BDS-3 卫星实际钟差 = `param(14) + param(20)`
- DCB 仍共享 `param(15)`, `param(16)`

> **推荐方案 A**：虽然改动稍大，但与现有 GPS/GLO/GAL/BDS/QZSS 五系统各 3 参数的对称结构一致，更清晰、易维护。如果 BDS-2 和 BDS-3 使用不同频率组合，独立 DCB 也是必要的。

### 3.3 BDS-2/BDS-3 卫星分类方法

新增一个通用工具函数 `isBDS2sat(prn)` / `isBDS3sat(prn)`：

```matlab
function is2 = isBDS2sat(prn)
% BDS-2 卫星: C01-C18 (PRN 1-18 or internal 301-318)
    sv = mod(prn, 100);
    is2 = sv >= 1 & sv <= 18;
end

function is3 = isBDS3sat(prn)
% BDS-3 卫星: C19-C62 (PRN 19-62 or internal 319-362+)
    sv = mod(prn, 100);
    is3 = sv >= 19 & sv <= 62;
end
```

> 注：BDS-2 PRN 范围为 C01-C18（GEO: C01-C05, IGSO: C06-C10/C13/C16, MEO: C11/C12/C14）；BDS-3 PRN 范围为 C19-C62+。此分类与 IGS 卫星元数据一致。

---

## 4. 详细实施步骤

### 4.1 Phase 1：settings 结构与 GUI 层

#### 4.1.1 新增 settings 字段

在 `getSettingsFromGUI.m` 中新增：

```matlab
% BDS-2/BDS-3 ISB 分离估计
settings.BIASES.estimate_bds23_isb = false;   % 默认关闭
```

#### 4.1.2 GUI 控件（GUI_PPP.fig + GUI_PPP.m）

- 在 BDS 相关面板区域添加一个 checkbox：`checkbox_bds23_isb`
  - 标签文字："Estimate BDS-2/BDS-3 ISB separately"
  - 仅在 `checkbox_BDS` 勾选时启用
- 在 `checkbox_BDS_Callback` 中联动 enable/disable

#### 4.1.3 getSettingsFromGUI.m

```matlab
% BDS-2/BDS-3 ISB
if isfield(handles, 'checkbox_bds23_isb') && ishghandle(handles.checkbox_bds23_isb)
    settings.BIASES.estimate_bds23_isb = logical(get(handles.checkbox_bds23_isb, 'Value'));
else
    if ~isfield(settings.BIASES, 'estimate_bds23_isb')
        settings.BIASES.estimate_bds23_isb = false;
    end
end
```

#### 4.1.4 setSettingsToGUI.m

```matlab
if isfield(handles, 'checkbox_bds23_isb') && isfield(structure.BIASES, 'estimate_bds23_isb')
    set(handles.checkbox_bds23_isb, 'Value', structure.BIASES.estimate_bds23_isb);
end
```

#### 4.1.5 checkProcessingSettings.m

```matlab
% BDS-2/BDS-3 ISB：必须启用 BDS
if isfield(settings.BIASES, 'estimate_bds23_isb') && settings.BIASES.estimate_bds23_isb
    if ~settings.INPUT.use_BDS
        errordlg('BDS-2/BDS-3 ISB estimation requires BDS to be enabled.');
        settings.BIASES.estimate_bds23_isb = false;
    end
end

% 向后兼容
if ~isfield(settings.BIASES, 'estimate_bds23_isb')
    settings.BIASES.estimate_bds23_isb = false;
end
```

---

### 4.2 Phase 2：常量与 Epoch 层

#### 4.2.1 DEF.m

新增条件参数数量或直接增加：

```matlab
% 当启用 BDS-2/BDS-3 ISB 分离时的参数数量
NO_PARAM_ZD_BDS23 = 22;   % 19 + 3 (BDS-3 ISB, BDS-3 DCB12, BDS-3 DCB13)
NO_PARAM_DCM_BDS23 = 34;  % 29 + 5 (code/phase clk BDS-3, IFB BDS-3, L2/L3 bias BDS-3)
```

或者改为动态计算方式（推荐）：在 `initProcessing.m` 中根据 settings 决定 `Adjust.NO_PARAM`。

#### 4.2.2 Epoch 结构新增 BDS-2/BDS-3 识别

在 `RINEX2Epoch.m` 和 `RawSensor2Epoch.m` 中：

```matlab
% 在设置 Epoch.bds 之后新增：
if settings.BIASES.estimate_bds23_isb
    bds_sv = mod(Epoch.sats(Epoch.bds), 100);
    Epoch.bds2 = Epoch.bds & (mod(Epoch.sats, 100) >= 1 & mod(Epoch.sats, 100) <= 18);
    Epoch.bds3 = Epoch.bds & (mod(Epoch.sats, 100) >= 19);
else
    Epoch.bds2 = false(size(Epoch.sats));
    Epoch.bds3 = false(size(Epoch.sats));
end
```

---

### 4.3 Phase 3：处理核心

#### 4.3.1 initProcessing.m

```matlab
if settings.BIASES.estimate_bds23_isb
    Adjust.NO_PARAM = DEF.NO_PARAM_ZD + 3;  % 19 + 3 = 22
else
    Adjust.NO_PARAM = DEF.NO_PARAM_ZD;      % 19
end
```

#### 4.3.2 adjustmentPreparation_ZD.m

在参数向量初始化部分，当 `estimate_bds23_isb == true` 时，为索引 20-22 添加：
- `param_sigma(20,20) = FILTER.var_rclk_bds` （BDS-3 ISB 初始方差）
- `param_sigma(21,21) = FILTER.var_DCB` （BDS-3 DCB12）
- `param_sigma(22,22) = FILTER.var_DCB` （BDS-3 DCB13）

噪声矩阵和转移矩阵同样扩展。

#### 4.3.3 Designmatrix_ZD.m（**核心改动**）

```matlab
% 当前代码：
% dR_time_dcb(:,10) = isBDS;     % BDS 整体

% 改为：
if settings.BIASES.estimate_bds23_isb
    isBDS2 = repmat(Epoch.bds2, num_freq, 1);
    isBDS3 = repmat(Epoch.bds3, num_freq, 1);
    dR_time_dcb(:,10) = isBDS2;          % BDS-2 时间偏移（索引 14）
    dR_time_dcb(:,16) = isBDS3;          % BDS-3 时间偏移（索引 20）
    % DCB 部分也需分离：
    if settings.BIASES.estimate_rec_dcbs
        if num_freq > 1
            dR_time_dcb(frq_2, 11) = -isBDS2(frq_2);  % BDS-2 DCB12（索引 15）
            dR_time_dcb(frq_2, 17) = -isBDS3(frq_2);  % BDS-3 DCB12（索引 21）
        end
        if num_freq > 2
            dR_time_dcb(frq_3, 12) = -isBDS2(frq_3);  % BDS-2 DCB13（索引 16）
            dR_time_dcb(frq_3, 18) = -isBDS3(frq_3);  % BDS-3 DCB13（索引 22）
        end
    end
else
    dR_time_dcb(:,10) = isBDS;     % 保持原样
end
```

> 注意：`dR_time_dcb` 的列数需要根据是否启用 BDS-2/3 ISB 动态调整（从 15 列变为 18 列），`NO_PARAM` 也相应变化。

#### 4.3.4 Designmatrix_code_ZD.m

同 Designmatrix_ZD.m 的对应修改。

#### 4.3.5 Designmatrix_DCM.m

在解耦钟模型中，将 `isBDS` 拆分为 `isBDS2` 和 `isBDS3`：
- code clock: BDS-2 和 BDS-3 各一列
- phase clock: BDS-2 和 BDS-3 各一列
- IFB/L2 bias/L3 bias 同理

#### 4.3.6 modelErrorSources.m

```matlab
% 当前：
% dt_rx = (param(5) + isGLO*param(8) + isGAL*param(11) + isBDS*param(14) + isQZSS*param(17))/Const.C;

% 改为：
if settings.BIASES.estimate_bds23_isb
    isBDS2_i = Epoch.bds2(i_sat);
    isBDS3_i = Epoch.bds3(i_sat);
    dt_rx = (param(5) + isGLO*param(8) + isGAL*param(11) + ...
             isBDS2_i*param(14) + isBDS3_i*param(20) + ...
             isQZSS*param(17)) / Const.C;
else
    dt_rx = (param(5) + isGLO*param(8) + isGAL*param(11) + ...
             isBDS*param(14) + isQZSS*param(17)) / Const.C;
end
```

#### 4.3.7 modelApproximately.m

同 modelErrorSources.m 的对应修改。

---

### 4.4 Phase 4：输出与可视化

#### 4.4.1 saveData.m

`storeData.param(q,:)` 已按 `NO_PARAM` 存储，无需特殊改动。新增的 3 个参数会自动存入 `param(20:22)`。

需检查 `storeData.param` 的初始化维度是否随 `NO_PARAM` 动态调整（在 `initProcessing.m` 中，`storeData.param = zeros(tot_eps, Adjust.NO_PARAM)` 已是动态的）。

#### 4.4.2 settings2txt.m

新增输出行：

```matlab
if isfield(settings.BIASES, 'estimate_bds23_isb') && settings.BIASES.estimate_bds23_isb
    fprintf(fileID, '    BDS-2/BDS-3 ISB: Estimated separately\n');
    fprintf(fileID, '    %s%11.3f%s%11.3f%s%d\n', 'Receiver Clock BDS-2:', ...
        sqrt(settings.ADJ.filter.var_rclk_bds), ' | ', ...
        sqrt(settings.ADJ.filter.Q_rclk_bds),  ' | ', ...
        settings.ADJ.filter.dynmodel_rclk_bds);
    fprintf(fileID, '    %s%11.3f%s%11.3f%s%d\n', 'Receiver Clock BDS-3:', ...
        sqrt(settings.ADJ.filter.var_rclk_bds3), ' | ', ...
        sqrt(settings.ADJ.filter.Q_rclk_bds3),  ' | ', ...
        settings.ADJ.filter.dynmodel_rclk_bds3);
end
```

#### 4.4.3 create_output.m

若有 BDS-2/BDS-3 ISB 序列输出需求，可导出时间序列。

#### 4.4.4 新增 GUI 绘图控件 — `checkbox_plot_bds23_isb`

在 Single-Plot 面板的 **Estimated Parameters** 区域（与 `checkbox_plot_clock` / `checkbox_plot_dcb` 同区），新增一个绘图开关：

- **控件名**：`checkbox_plot_bds23_isb`
- **标签文字**：`BDS-2/3 ISB`
- **位置**：紧邻 Clock / DCB / Wet Tropo 等绘图 checkbox 下方
- **仅在 BDS 和 BDS-2/3 ISB 估计同时启用时激活**

**联动逻辑**（`GUI_PPP.m`）：
```matlab
% 在 checkbox_BDS_Callback 或相关位置：
if isfield(handles, 'checkbox_plot_bds23_isb')
    if settings.INPUT.use_BDS && settings.BIASES.estimate_bds23_isb
        set(handles.checkbox_plot_bds23_isb, 'Enable', 'On');
    else
        set(handles.checkbox_plot_bds23_isb, 'Enable', 'Off', 'Value', 0);
    end
end
```

**getSettingsFromGUI.m** 新增：
```matlab
settings.PLOT.bds23_isb = get(handles.checkbox_plot_bds23_isb, 'Value');
```

**setSettingsToGUI.m** 新增：
```matlab
try
    set(handles.checkbox_plot_bds23_isb, 'Value', structure.PLOT.bds23_isb);
catch
    % old version without BDS-2/3 ISB plotting
end
```

#### 4.4.5 新建绘图函数 — `vis_plotBDS23ISB.m`

新建文件 `CODE/VISUAL/vis_plotBDS23ISB.m`，参照 `vis_plotReceiverClock.m` 的模式实现，生成以下 **3 个子图**：

##### 子图 1：BDS-2/BDS-3 ISB 时序图（ISB Sequence）

对应论文 **图 5**（各系统与 BDS-2 单天内 ISB 序列），绘制 BDS-3 相对 BDS-2（或 GPS）的 ISB 时间序列。

```matlab
function vis_plotBDS23ISB(hours, strXAxis, param, resets_h, settings, storeData)
% Plots BDS-2/BDS-3 ISB analysis:
%   Sub1: ISB time series (BDS-3 offset - BDS-2 offset)
%   Sub2: Hourly ISB mean statistics
%   Sub3: ISB histogram / distribution
%
% INPUT:
%   hours       vector, time in hours from beginning of processing
%   strXAxis    label for x-axis
%   param       estimated parameters [epochs × NO_PARAM]  (transposed)
%   resets_h    vector, time of resets in hours
%   settings    struct, processing settings from GUI
%   storeData   struct, collected data
% OUTPUT: []

m2ns = 1e9 / Const.C;    % [m] → [ns]
m2m  = 1;                 % keep [m]

% --- 提取 BDS-2 和 BDS-3 接收机钟差参数 ---
rec_clk_BDS2 = param(14,:);   % BDS-2 时间偏移 [m]
rec_clk_BDS3 = param(20,:);   % BDS-3 时间偏移 [m]

% --- 计算 ISB = BDS-3 offset - BDS-2 offset ---
ISB_C23 = (rec_clk_BDS3 - rec_clk_BDS2);  % [m]
valid = (rec_clk_BDS2 ~= 0) & (rec_clk_BDS3 ~= 0);  % 有效历元

% 也可计算各系统相对于 BDS-2 的差值
rec_clk_GPS = param(5,:);
rec_clk_GLO = param(8,:);
rec_clk_GAL = param(11,:);

fig = figure('Name','BDS-2/BDS-3 ISB Analysis', 'NumberTitle','off');

%% ---- 子图1：ISB 时间序列（对应论文图5） ----
subplot(3,1,1)
hold on

% 绘制各系统与 BDS-2 的 ISB 序列
if settings.INPUT.use_GPS
    ISB_G_C2 = rec_clk_GPS - rec_clk_BDS2;  % GPS - BDS-2
    v = (rec_clk_GPS ~= 0) & (rec_clk_BDS2 ~= 0);
    plot(hours(v), ISB_G_C2(v)*m2m, 'r-', 'DisplayName', 'GPS - BDS-2');
end
if settings.INPUT.use_GLO
    ISB_R_C2 = rec_clk_GLO - rec_clk_BDS2;
    v = (rec_clk_GLO ~= 0) & (rec_clk_BDS2 ~= 0);
    plot(hours(v), ISB_R_C2(v)*m2m, 'c-', 'DisplayName', 'GLO - BDS-2');
end
if settings.INPUT.use_GAL
    ISB_E_C2 = rec_clk_GAL - rec_clk_BDS2;
    v = (rec_clk_GAL ~= 0) & (rec_clk_BDS2 ~= 0);
    plot(hours(v), ISB_E_C2(v)*m2m, 'b-', 'DisplayName', 'GAL - BDS-2');
end
% BDS-3 - BDS-2 (核心 ISB)
plot(hours(valid), ISB_C23(valid)*m2m, 'm-', 'LineWidth', 1.5, ...
    'DisplayName', 'BDS-3 - BDS-2');

legend('show', 'Location', 'best')
title('ISB Sequence of Each System and BDS-2')
xlabel(strXAxis); ylabel('ISB [m]')
grid on; xlim([hours(1) hours(end)])
if ~isempty(resets_h); vline(resets_h, 'k:'); end

%% ---- 子图2：逐小时 ISB 均值统计（对应论文图6/图7） ----
subplot(3,1,2)
hold on

% 将数据按小时分箱
hour_edges = floor(min(hours)):1:ceil(max(hours));
n_bins = length(hour_edges) - 1;
isb_hourly_mean = zeros(1, n_bins);
isb_hourly_std  = zeros(1, n_bins);

for k = 1:n_bins
    idx = valid & (hours >= hour_edges(k)) & (hours < hour_edges(k+1));
    if any(idx)
        isb_hourly_mean(k) = mean(ISB_C23(idx)) * m2m;
        isb_hourly_std(k)  = std(ISB_C23(idx)) * m2m;
    else
        isb_hourly_mean(k) = NaN;
        isb_hourly_std(k)  = NaN;
    end
end

hour_centers = hour_edges(1:end-1) + 0.5;
bar(hour_centers, isb_hourly_mean, 0.8, 'FaceColor', [0.8 0.4 1], 'FaceAlpha', 0.7)
errorbar(hour_centers, isb_hourly_mean, isb_hourly_std, 'k.', 'LineWidth', 1)

% 绘制全天均值参考线
overall_mean = mean(ISB_C23(valid)) * m2m;
yline(overall_mean, 'r--', sprintf('Mean=%.3f m', overall_mean), 'LineWidth', 1.5);

title('Hourly Mean of BDS-2/BDS-3 ISB')
xlabel(strXAxis); ylabel('ISB [m]')
grid on; xlim([hours(1) hours(end)])

%% ---- 子图3：ISB 分布直方图 + 统计摘要 ----
subplot(3,1,3)
hold on

isb_valid = ISB_C23(valid) * m2m;
histogram(isb_valid, 'Normalization', 'probability', 'FaceColor', [0.8 0.4 1], 'FaceAlpha', 0.7)
xline(mean(isb_valid), 'r-', 'LineWidth', 2)
xline(median(isb_valid), 'b--', 'LineWidth', 1.5)

% 统计文字
stats_str = sprintf('Mean=%.3f m, STD=%.3f m, Median=%.3f m', ...
    mean(isb_valid), std(isb_valid), median(isb_valid));
title({'BDS-2/BDS-3 ISB Distribution', stats_str})
xlabel('ISB [m]'); ylabel('Probability')
legend('Distribution', 'Mean', 'Median', 'Location', 'best')
grid on

% 添加 datatip
dcm = datacursormode(fig);
datacursormode on
set(dcm, 'updatefcn', @vis_customdatatip_h)

end
```

##### 关键设计要点

| 子图 | 对应论文 | 内容 | X轴 | Y轴 |
|------|---------|------|-----|------|
| 1 | 图5 | 各系统与BDS-2的ISB时间序列 | 时间 [h] | ISB [m] |
| 2 | 图6/图7 | BDS-2/3 ISB逐小时均值+标准差 | 时间 [h] | ISB [m] |
| 3 | — | ISB分布直方图 + 统计摘要 | ISB [m] | 概率 |

##### 颜色方案

| 曲线 | 颜色 | 含义 |
|------|------|------|
| GPS - BDS-2 | 红色 `r-` | GPS 与 BDS-2 的时间偏移差 |
| GLO - BDS-2 | 青色 `c-` | GLONASS 与 BDS-2 的时间偏移差 |
| GAL - BDS-2 | 蓝色 `b-` | Galileo 与 BDS-2 的时间偏移差 |
| **BDS-3 - BDS-2** | **品红色粗线 `m-`** | **核心 ISB（加粗 1.5pt）** |

#### 4.4.6 SinglePlotting.m 中调用新绘图

在 `SinglePlotting.m` 的 Clock Plot 和 DCB Plot 之间（约 L185 附近），新增如下调用块：

```matlab
% -+-+-+-+- Figure: BDS-2/BDS-3 ISB Plot -+-+-+-+-
if isfield(settings.PLOT, 'bds23_isb') && settings.PLOT.bds23_isb
    if isfield(settings.BIASES, 'estimate_bds23_isb') && settings.BIASES.estimate_bds23_isb
        vis_plotBDS23ISB(hours, label_x_h, storeData.param', reset_h, settings, storeData);
    else
        fprintf('BDS-2/BDS-3 ISB was not estimated.\n');
    end
end
if STOP_CALC; return; end
```

#### 4.4.7 vis_plotReceiverClock.m 适配

当 BDS-2/3 ISB 分离启用时，Clock Plot 需显示 **两条 BDS 曲线**而非一条：

```matlab
% 在 "plot Beidou" 部分修改：
if isBDS
    if isfield(settings.BIASES, 'estimate_bds23_isb') && settings.BIASES.estimate_bds23_isb
        % BDS-2 clock
        rec_clk_BDS2 = param(14,:) * m2ns;
        i = plot_clk(rec_clk_BDS2, i, n+1, m, resets_h, hours, strXAxis, ...
            ['BDS-2 ' strYAxis], [0.8 0 0.8]);  % 深品红
        % BDS-3 clock
        rec_clk_BDS3 = param(20,:) * m2ns;
        i = plot_clk(rec_clk_BDS3, i, n+1, m, resets_h, hours, strXAxis, ...
            ['BDS-3 ' strYAxis], [1 0.4 1]);     % 浅品红
    else
        i = plot_clk(rec_clk_BDS, i, n, m, resets_h, hours, strXAxis, ...
            ['BDS ' strYAxis], DEF.COLOR_C);
    end
end
```

> 注意：subplot 行数 `n` 需根据 BDS-2/3 分离增加 1。

#### 4.4.8 vis_plotReceiverDCBs.m 适配

当启用 BDS-2/3 ISB 时，DCB 绘图也需分离：

```matlab
% 原来：
% if isBDS
%     leg_cell = plot_DCBs(leg_cell, hours, param(15,:), param(16,:), ...
%         'BDS', 'm', no_dcbs, obs.BDS);
% end

% 改为：
if isBDS
    if isfield(settings.BIASES, 'estimate_bds23_isb') && settings.BIASES.estimate_bds23_isb
        leg_cell = plot_DCBs(leg_cell, hours, param(15,:), param(16,:), ...
            'BDS-2', [0.8 0 0.8], no_dcbs, obs.BDS);
        leg_cell = plot_DCBs(leg_cell, hours, param(21,:), param(22,:), ...
            'BDS-3', [1 0.4 1], no_dcbs, obs.BDS);
    else
        leg_cell = plot_DCBs(leg_cell, hours, param(15,:), param(16,:), ...
            'BDS', 'm', no_dcbs, obs.BDS);
    end
end
```

#### 4.4.9 covParaPlot.m 适配

在参数标准差绘图的 "Receiver Clock and Offsets" 部分，当 BDS-2/3 分离时新增 BDS-3 曲线：

```matlab
% 在 BDS 绘制后追加：
if isfield(settings.BIASES, 'estimate_bds23_isb') && settings.BIASES.estimate_bds23_isb
    BDS3_rec_clk_code = std_param(20,:);
    if any(~isnan(BDS3_rec_clk_code))
        plot(hours, BDS3_rec_clk_code, 'm--', 'LineWidth', 1.2);
        leg_txt_clk{end+1} = 'dt_{rec}^{C3}';
    end
end
```

---

### 4.5 Phase 5：滤波器参数

#### 4.5.1 LoadDefaultFilterSettings.m

BDS-3 ISB 的滤波参数可直接复用 BDS 的默认值：
- 初始方差：`var_rclk_bds3 = var_rclk_bds`
- 过程噪声：`Q_rclk_bds3 = Q_rclk_bds`
- 动态模型：`dynmodel_rclk_bds3 = dynmodel_rclk_bds`

或者使用独立的随机模型（论文提到 BDS-2/3 ISB 在天内较稳定，可选择 random walk 或常数模型）：
- **白噪声模型**（dynmodel = 0）：每历元重新估计，适用于数据质量较差的智能手机
- **随机游走模型**（dynmodel = 1, 小过程噪声）：适用于短时间内 ISB 较稳定的场景
- **常数模型**（dynmodel = 1, Q = 0）：适用于 ISB 日内稳定的场景

推荐默认使用**白噪声模型**以匹配智能手机特性。

---

## 5. 文件修改清单

| # | 文件路径 | 改动类型 | 说明 |
|---|---------|----------|------|
| 1 | `CODE/COMMON/DEF.m` | 新增常量 | `NO_PARAM_ZD_BDS23`, PRN 分类常量 |
| 2 | `CODE/COMMON/isBDS2sat.m` | **新建** | BDS-2 卫星判别函数 |
| 3 | `CODE/COMMON/isBDS3sat.m` | **新建** | BDS-3 卫星判别函数 |
| 4 | `CODE/VISUAL/GUI/GUI_PPP.fig` | 修改 | 新增 checkbox 控件 |
| 5 | `CODE/VISUAL/GUI/GUI_PPP.m` | 修改 | 新增回调、联动 |
| 6 | `CODE/READ/getSettingsFromGUI.m` | 修改 | 读取 BDS-2/3 ISB 开关 |
| 7 | `CODE/VISUAL/GUI/setSettingsToGUI.m` | 修改 | 回填 BDS-2/3 ISB 开关 |
| 8 | `CODE/READ/checkProcessingSettings.m` | 修改 | 校验 + 向后兼容 |
| 9 | `CODE/PROCESSING/initProcessing.m` | 修改 | 动态 NO_PARAM |
| 10 | `CODE/PROCESSING/RINEX2Epoch.m` | 修改 | 新增 Epoch.bds2/bds3 |
| 11 | `CODE/PROCESSING/RawSensor2Epoch.m` | 修改 | 新增 Epoch.bds2/bds3 |
| 12 | `CODE/PROCESSING/adjustmentPreparation_ZD.m` | 修改 | 扩展状态向量/协方差/噪声/转移矩阵 |
| 13 | `CODE/PROCESSING/Designmatrix_ZD.m` | **核心修改** | 设计矩阵拆分 BDS-2/3 |
| 14 | `CODE/PROCESSING/Designmatrix_code_ZD.m` | **核心修改** | 纯码解设计矩阵拆分 |
| 15 | `CODE/PROCESSING/Designmatrix_DCM.m` | 修改 | 解耦钟模型拆分 |
| 16 | `CODE/PROCESSING/modelErrorSources.m` | **核心修改** | 观测模型中 BDS-2/3 分别使用参数 |
| 17 | `CODE/PROCESSING/modelApproximately.m` | 修改 | 近似模型中 BDS-2/3 分别使用参数 |
| 18 | `CODE/PROCESSING/saveData.m` | 检查/微调 | 确保 NO_PARAM 动态适配 |
| 19 | `CODE/PROCESSING/settings2txt.m` | 修改 | 导出 BDS-2/3 ISB 信息 |
| 20 | `CODE/VISUAL/covParaPlot.m` | 修改 | 绘制 BDS-3 时间偏移标准差曲线 |
| 21 | `CODE/VISUAL/GUI/LoadDefaultFilterSettings.m` | 修改 | BDS-3 ISB 默认滤波参数 |
| 22 | `CODE/PROCESSING/create_output.m` | 可选修改 | 导出 ISB 序列 |
| 23 | `CODE/VISUAL/vis_plotBDS23ISB.m` | **新建** | BDS-2/3 ISB 专用绘图函数（3子图） |
| 24 | `CODE/VISUAL/SinglePlotting.m` | 修改 | 新增 BDS-2/3 ISB 绘图调用入口 |
| 25 | `CODE/VISUAL/vis_plotReceiverClock.m` | 修改 | BDS-2/BDS-3 双曲线 Clock 绘制 |
| 26 | `CODE/VISUAL/vis_plotReceiverDCBs.m` | 修改 | BDS-2/BDS-3 分离 DCB 绘制 |

---

## 6. 参数索引映射（方案 A 启用时）

| 索引 | 参数 | 说明 |
|------|------|------|
| 1-3 | X, Y, Z | 坐标 |
| 4 | ZWD | 对流层 |
| 5-7 | dt_GPS, DCB_G12, DCB_G13 | GPS |
| 8-10 | dt_GLO, DCB_R12, DCB_R13 | GLONASS |
| 11-13 | dt_GAL, DCB_E12, DCB_E13 | Galileo |
| 14-16 | dt_BDS2, DCB_C2_12, DCB_C2_13 | **BDS-2** |
| 17-19 | dt_QZSS, DCB_J12, DCB_J13 | QZSS |
| **20-22** | **dt_BDS3, DCB_C3_12, DCB_C3_13** | **BDS-3（新增）** |
| 23+ | N_i | 模糊度 |

---

## 7. 风险与注意事项

### 7.1 向后兼容性
- 旧 `settings.mat` 中不含 `estimate_bds23_isb` 字段 → 在 `checkProcessingSettings.m` 中用 `isfield` 默认设为 `false`
- 旧的 `storeData` 无第 20-22 列 → 加载旧结果时需要判断列数

### 7.2 模糊度固定
- 若启用 BDS-2/3 分离 ISB，模糊度参数起始索引从 `NO_PARAM+1` 变为 22+1=23 → 需检查所有引用 `Adjust.NO_PARAM` 的模糊度索引逻辑
- BDS 参考星选择逻辑可能需要区分 BDS-2/BDS-3

### 7.3 DCM（解耦钟模型）
- DCM 的参数更多（29 → 34+），改动量更大，可作为第二阶段实现
- 建议第一阶段先仅支持 ZD 模式

### 7.4 频率差异
- BDS-2 主要使用 B1I(B1), B2I(B2), B3I(B3) 频段
- BDS-3 主要使用 B1C(B1AC), B2a(B2a), B1I(B1), B3I(B3) 频段  
- 当 BDS-2 和 BDS-3 使用相同频率（如 B1I）时，ISB 才有意义且可被双差消除
- 当使用不同频率时，DCB 也会不同，这是方案 A（独立 DCB）的优势所在

### 7.5 智能手机特殊性
- 论文指出智能手机 BDS-2/3 ISB 可达 1m+，建议对智能手机数据默认启用此功能
- 可在 `RawSensor2Epoch.m` 中检测到 Android 原始数据时自动提示

---

## 8. 测试验证计划

### 8.1 单元测试
1. 验证 `isBDS2sat`/`isBDS3sat` 对全部 BDS PRN 的正确分类
2. 验证启用/禁用开关时参数向量维度正确
3. 验证设计矩阵中 BDS-2/BDS-3 列的正确性

### 8.2 集成测试
1. 使用包含 BDS-2+BDS-3 卫星的 RINEX 观测文件进行处理
2. 对比启用/禁用 BDS-2/3 ISB 分离的定位精度
3. 检查估计出的 ISB 序列是否合理（专业接收机应接近0，智能手机可达 1m+）

### 8.3 回归测试
1. 关闭 BDS-2/3 ISB 功能，确保与修改前结果完全一致
2. 加载旧 `settings.mat`，确保不报错
3. 验证所有 GNSS 组合（GPS-only, GPS+BDS, GRECJ 等）正常工作

### 8.4 验证脚本

编写 `test_bds23_isb.m` 脚本：
```matlab
% 1. 构造 Epoch 数据，包含 BDS-2 和 BDS-3 卫星
% 2. 验证 Epoch.bds2 和 Epoch.bds3 正确
% 3. 构造设计矩阵，验证 BDS-2/3 参数列独立
% 4. 模拟 1m 的 BDS-2/3 ISB，验证估计器能正确分离
```

---

## 9. 实施优先级与时间估计

| 阶段 | 内容 | 预估工时 |
|------|------|---------|
| Phase 1 | settings + GUI + 校验 | 2-3h |
| Phase 2 | DEF + Epoch + 工具函数 | 1-2h |
| Phase 3 | 设计矩阵 + 观测模型 + 滤波器 | 4-6h |
| Phase 4 | 输出 + 可视化（含 ISB 专用绘图函数） | 3-5h |
| Phase 5 | 测试 + 验证 | 3-4h |
| **总计** | | **13-20h** |

建议先实现 ZD 模式（Phase 1-4），DCM 模式作为后续迭代。
