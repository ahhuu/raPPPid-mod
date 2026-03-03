# BDS-2/BDS-3 ISB 分离估计功能说明

## 1. 背景

在 raPPPid 原始实现中，所有北斗卫星（C01–C62）共享**一组**接收机时钟偏移和 DCB 参数：

| 原始参数索引 | 含义 | 备注 |
|---|---|---|
| `param(14)` | dt_BDS — 北斗接收机钟差偏移 | 所有 BDS 卫星共用 |
| `param(15)` | DCB_C_12 — 北斗频率 1-2 差分码偏差 | 所有 BDS 卫星共用 |
| `param(16)` | DCB_C_13 — 北斗频率 1-3 差分码偏差 | 所有 BDS 卫星共用 |

但 BDS-2（C01–C18，2G+3I+10M 卫星）和 BDS-3（C19–C62，24M+3I+3G 卫星）使用**不同的原子钟体制**（BDS-2 采用铷钟，BDS-3 采用氢钟/铷钟混合），且信号体制有差异（BDS-2 的 B1I/B2I/B3I 与 BDS-3 的 B1C/B2a/B3I），导致两代卫星之间存在一个**系统性的接收机端偏差**，即 **Inter-System Bias (ISB)**。若不分离估计，该偏差会污染定位结果。

---

## 2. 新增参数

启用功能后，参数向量从 19 维扩展到 20 维（`NO_PARAM_ZD: 19 → 20`）。

采用"公共 BDS 钟差 + ISB"参数化方式，仅新增 1 个参数：

| 索引 | 新参数符号 | 含义 | 滤波模型 |
|---|---|---|---|
| `param(20)` | 模式相关参数 | 在 free/constrained 下表示 BDS-3 相对公共 BDS 钟差的 ISB；在 split 下表示 BDS-3 独立钟差参数 | 支持四种模式：**free**（白噪声，默认）、**split**（独立BDS2/BDS3时钟参数化）、**constrained**（标定先验约束）或 **fixed**（固定改正，不估计状态） |

原有 `param(14)`–`param(16)` 的语义**变为 BDS 公共参数**：

| 索引 | 启用后含义 |
|---|---|
| `param(14)` | dt_BDS_common — BDS 公共接收机钟差偏移（所有 BDS 卫星都贡献） |
| `param(15)` | DCB_C_12 — BDS 共享频率 1-2 DCB（BDS-2 和 BDS-3 共用） |
| `param(16)` | DCB_C_13 — BDS 共享频率 1-3 DCB（BDS-2 和 BDS-3 共用） |

> **设计理由**：
> 1. 让 param(14) 使用全部 BDS 卫星（10+颗）来估计公共钟差，
>    而非仅用 BDS-2（智能手机通常仅 2-3 颗），显著改善参数可观测性。
> 2. ISB 支持四种模式：
>    - **free**（默认）：白噪声，复用 BDS 钟差滤波设置，每历元独立估计。
>      需要 BDS-2 ≥ 4 颗才能几何可观测。
>    - **split**：将 BDS-2 与 BDS-3 作为独立子系统时钟处理，
>      不需要输入 prior/fixed 数值，适合希望避免显式 ISB 标定值注入的场景。
>    - **constrained**：以标定值为先验的随机常数（Transition=1，Noise=0.001 m²/h），
>      小初始方差（σ²_prior）约束 ISB 在标定值附近，避免几何秩亏导致的高度退化。
>      适用于 BDS-2 不足的智能手机场景。
>    - **fixed**：对 BDS-3 施加固定 ISB 改正值 `bds23_isb_fixed_m`，不引入 `param(20)` 状态，
>      适用于短时段/弱几何场景（如 20 分钟手机数据）。
> 3. DCB 不再分 BDS-2/BDS-3 单独估计（共享），减少参数数量。

---

## 3. 数学模型变化

**原始 ZD 模型**中，对一颗 BDS 卫星 s 的伪距观测方程：

```
ρ^s = |r_rec - r^s| + c·dt_GPS + c·dt_BDS - c·dt^s + T + I + ε
```

**启用 ISB 后**，根据模式有两类参数化：

- free / constrained / fixed：采用"公共 BDS 钟差 + ISB"参数化
- split：采用"BDS-2 与 BDS-3 独立钟差"参数化

### 3.1 free / constrained / fixed

- BDS-2 卫星（s ∈ C01–C18）：
```
ρ^s = |r_rec - r^s| + c·dt_GPS + c·dt_BDS_common - c·dt^s + T + I + ε
```

- BDS-3 卫星（s ∈ C19–C62）：
```
ρ^s = |r_rec - r^s| + c·dt_GPS + c·dt_BDS_common + c·ISB_BDS3 - c·dt^s + T + I + ε
```

其中 `dt_BDS_common` 由所有 BDS 卫星共同约束，`ISB_BDS3` 仅由 BDS-3 卫星约束。

BDS-2/BDS-3 的 ISB 即为：
```
ISB_BDS2/3 = ISB_BDS3 = param(20)
```

### 3.2 split（独立 BDS-2/BDS-3 时钟）

- BDS-2 卫星（s ∈ C01–C18）：
```
ρ^s = |r_rec - r^s| + c·dt_GPS + c·dt_BDS_2 - c·dt^s + T + I + ε
```

- BDS-3 卫星（s ∈ C19–C62）：
```
ρ^s = |r_rec - r^s| + c·dt_GPS + c·dt_BDS_3 - c·dt^s + T + I + ε
```

此时 `param(14)` 对应 `dt_BDS_2`，`param(20)` 对应 `dt_BDS_3`；两者差值可解释为隐式 ISB：
```
ISB_BDS2/3 = dt_BDS_3 - dt_BDS_2
```

---

## 4. 卫星分类规则

| 类别 | PRN 范围 | raPPPid 内部编号 | 代表卫星 |
|---|---|---|---|
| BDS-2 | C01–C18 | 301–318 | C01–C05 (GEO), C06–C10 (IGSO), C11–C14 (MEO) |
| BDS-3 | C19–C62 | 319–362 | C19–C30 (MEO), C38–C40 (IGSO), C59–C61 (GEO) |

实现为两个工具函数 `isBDS2sat(prn)` 和 `isBDS3sat(prn)`（位于 `CODE/COMMON/`），支持两种 PRN 记法。

---

## 5. 设计矩阵结构

启用前，`dR_time_dcb` 矩阵为 (s × f) × 15 列：

```
列:  1       2       3     | 4       5       6     | 7       8       9     | 10      11      12    | 13      14      15
     GPS钟  GPS_D12 GPS_D13  GLO钟  GLO_D12 GLO_D13  GAL钟  GAL_D12 GAL_D13  BDS钟  BDS_D12 BDS_D13  QZSS钟 QZSS_D12 QZSS_D13
```

启用后，扩展为 (s × f) × 16 列（列16对应 `param(20)`）：

```
列:  1-15 同上（BDS列10-12中：列10填全部BDS，列11-12填全部BDS DCB）  | 16
                                                                        BDS3_ISB
```

> **注意（按模式区分）**：
> - free/constrained/fixed：列10 (param14) 对所有 BDS 卫星为 1（公共 BDS 钟差）；列16 (param20) 对 BDS-3 为 1（ISB/额外项）。
> - split：列10 (param14) 仅对 BDS-2 为 1（`dt_BDS_2`）；列16 (param20) 仅对 BDS-3 为 1（`dt_BDS_3`）。
> - 列11-12 (param15-16) 在各模式下均为 BDS 共享 DCB。

---

## 6. 设置字段一览

| 设置路径 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `settings.BIASES.estimate_bds23_isb` | logical | `false` | 主开关：是否启用 BDS-2/3 ISB 分离估计 |
| `settings.BIASES.bds23_isb_mode` | string | `'free'` | ISB 模式：`'free'`（白噪声）/ `'split'`（独立 BDS2/BDS3 时钟）/ `'constrained'`（先验约束）/ `'fixed'`（固定改正） |
| `settings.BIASES.bds23_isb_prior_m` | double | `0` | 标定 ISB 先验值 [m]（仅 constrained 模式使用） |
| `settings.BIASES.bds23_isb_prior_sigma_m` | double | `3.0` | ISB 先验标准差 [m]（仅 constrained 模式使用） |
| `settings.BIASES.bds23_isb_fixed_m` | double | `0` | 固定 ISB 改正值 [m]（仅 fixed 模式使用） |
| `settings.PLOT.bds23_isb` | logical | `false` | 绘图开关：是否绘制 ISB 分析图 |

---

## 7. 前置条件与约束

- **必须启用 BDS** — 若 `settings.INPUT.use_BDS = false`，自动禁用
- **不支持 Decoupled Clock Model (DCM)** — 若电离层模型为 `'Estimate, decoupled clock'`，自动禁用
- **适用于 ZD（Zero-Difference）模型** — 包括 IF-LC、uncombined、3-Frequency-IF-LC 等
- **滤波参数复用** — free/constrained 模式下，BDS-3 ISB 状态复用 BDS 钟差滤波设置；split/fixed 模式不使用该先验输入
- **⚠️ 需要充足的 BDS-2 卫星** — 见下方"已知限制"章节

---

## 8. 使用方案

### 方法一：通过 GUI 启用（推荐）

GUI 中已集成两个 checkbox 控件，可直接在界面中启用：

1. **启动 raPPPid**
   ```matlab
   cd('D:\code\matlab\raPPPid\raPPPid\WORK');
   raPPPid
   ```

2. **配置基本参数**
   - Constellation: 勾选 **BDS**（必须）
   - 电离层模型: 选择非 DCM 的任意模型（如 `Estimate with ... as constraint`）
   - 其他设置按需配置

3. **启用 ISB 分离估计**
   - 切换到 **Adjustment / Filter** 面板
   - 勾选 **☑ BDS-2/3 ISB** 复选框（位于 Receiver Clock BeiDou 与 Receiver DCBs 之间）
   - 勾选后，右侧出现 **模式下拉菜单**，可选择 `free`、`split`、`constrained` 或 `fixed`

4. **选择 ISB 模式**
   - **free**（默认）：白噪声，每历元独立估计。需 BDS-2 ≥ 4 颗。
   - **split**：独立 BDS-2/BDS-3 时钟参数化，不需要填写 Prior/Sigma/Fixed。
   - **constrained**：标定先验约束。选择后右侧出现 **Prior[m]** 和 **Sigma[m]** 编辑框，
     可直接输入标定值（也可通过 `calibrate_bds23_isb.m` 自动写入 `settings.mat` 后 Load）。
   - **fixed**：固定改正。选择后右侧出现 **Fixed[m]** 编辑框，填入标定中位值。

5. **启用 ISB 绘图**（可选）
   - 切换到 **Single Plot** 面板
   - 勾选 **☑ BDS-2/3 ISB** 复选框（位于 Estimated Parameters 区域）
   - 注意：该复选框仅在步骤 3 启用估计后才可勾选

6. **运行处理**
   - 点击 **RUN** 按钮开始处理

#### GUI 控件说明

| 控件 Tag | 所在面板 | 功能 | 初始状态 |
|----------|---------|------|----------|
| `checkbox_bds23_isb` | Adjustment / Filter | 主开关：启用 BDS-2/3 ISB 分离估计 | Enable=on, Value=0 |
| `popupmenu_bds23_isb_mode` | Adjustment / Filter | 模式选择：free / split / constrained / fixed | Enable=off（动态创建） |
| `edit_bds23_isb_prior` | Adjustment / Filter | ISB 先验值 [m]（constrained 模式） | Visible=off（动态创建） |
| `edit_bds23_isb_sigma` | Adjustment / Filter | ISB 先验标准差 [m]（constrained 模式） | Visible=off（动态创建） |
| `edit_bds23_isb_fixed` | Adjustment / Filter | 固定 ISB 改正值 [m]（fixed 模式） | Visible=off（动态创建） |
| `checkbox_plot_bds23_isb` | Single Plot | 绘图开关：启用 ISB 分析图 | Enable=off, Value=0 |

**联动逻辑**：
- 勾选 checkbox → 下拉菜单启用、绘图 checkbox 可用
- 取消勾选 → 下拉菜单禁用、先验字段隐藏、绘图 checkbox 置灰
- 下拉选 constrained → 显示 Prior[m] 和 Sigma[m] 编辑框
- 下拉选 fixed → 显示 Fixed[m] 编辑框
- 下拉选 free/split → 隐藏 Prior/Sigma 编辑框
- 下拉选 free/constrained 时隐藏 Fixed[m] 编辑框
- 选 constrained 但 Prior=0 时弹出提示

### 方法二：批处理脚本中启用

```matlab
%% 在批处理脚本中启用

% 加载基础 settings
load('WORK/settings.mat', 'settings');

% 启用 BDS-2/3 ISB
settings.BIASES.estimate_bds23_isb = true;
settings.PLOT.bds23_isb = true;

% 设置观测文件列表
obs_files = {
    'D:\data\obs\station1.obs'
    'D:\data\obs\station2.obs'
};

% 批量处理
for i = 1:numel(obs_files)
    settings.INPUT.file_obs = obs_files{i};
    PPP_main(settings);
end
```

### 方法三：命令行手动修改 settings.mat

```matlab
% 在 GUI 中配置好其他参数并 Save 后，在命令窗口执行：
load('settings.mat', 'settings');
settings.BIASES.estimate_bds23_isb = true;
settings.PLOT.bds23_isb = true;
save('settings.mat', 'settings');
% 然后在 GUI 中 Load 并 RUN
```

> **注意**：方法二、三适合无 GUI 环境或已有方法一中 GUI 控件之前的旧版本。

### 方法四：使用约束模式（Constrained Mode）

当 BDS-2 卫星不足（<4 颗，如智能手机场景）时，free 模式会导致高度退化。
可通过标定 ISB 并以先验约束引入来解决：

**步骤 1：标定 — 从已有结果提取 ISB**

```matlab
% 先用 free 模式（默认）跑一组已知坐标的数据
% 处理完成后运行标定脚本：
cd('D:\code\matlab\raPPPid\raPPPid\WORK');
calibrate_bds23_isb('D:\...\RESULTS\your_result_folder')
% 或不带参数，交互选择文件夹：
calibrate_bds23_isb
```

脚本会自动：
- 提取 ISB 中位数（默认不跳过历元）
- 打印统计信息和推荐设置值
- 可选：直接写入 `WORK/settings.mat`

**步骤 2：启用约束模式**

**方式 A：通过 GUI（推荐）**
1. 在 GUI 中 **Load** settings（标定脚本已自动写入）
2. 勾选 **☑ BDS-2/3 ISB** 复选框
3. 右侧下拉菜单选择 **constrained**
4. 确认 **Prior[m]** 和 **Sigma[m]** 编辑框中的值正确
5. 点击 **RUN**

**方式 B：命令行**
```matlab
% 标定脚本已自动写入，也可手动设置：
load('settings.mat', 'settings');
settings.BIASES.estimate_bds23_isb      = true;
settings.BIASES.bds23_isb_mode          = 'constrained';
settings.BIASES.bds23_isb_prior_m       = 6.3456;   % 标定值 [m]（示例 ~21ns）
settings.BIASES.bds23_isb_prior_sigma_m = 3.0;      % 先验标准差 [m]
save('settings.mat', 'settings');
```

**切换回 free 模式**：在 GUI 下拉菜单中选 `free`，或命令行 `settings.BIASES.bds23_isb_mode = 'free';`

### 方法五：使用固定改正模式（Fixed Mode，推荐用于短时段）

当短时段数据（如 20 分钟）下 `constrained` 仍明显劣化，可使用固定改正避免新增状态自由度。

**方式 A：GUI**
1. 勾选 **☑ BDS-2/3 ISB**
2. 下拉选择 **fixed**
3. 在 **Fixed[m]** 输入标定中位值（可来自 `calibrate_bds23_isb.m` 输出）
4. 点击 **RUN**

**方式 B：命令行**
```matlab
load('settings.mat', 'settings');
settings.BIASES.estimate_bds23_isb = true;
settings.BIASES.bds23_isb_mode     = 'fixed';
settings.BIASES.bds23_isb_fixed_m  = 6.3456;  % 示例值 [m]
save('settings.mat', 'settings');
```

**约束模式滤波参数**：

| 参数 | Free 模式 | Constrained 模式 |
|------|-----------|-----------------|
| `param(20)` 初始值 | 0 | `bds23_isb_prior_m`（标定值） |
| `param_sigma(20,20)` | `var_rclk_bds`（极大） | `bds23_isb_prior_sigma_m²`（如 9 m²） |
| `Transition(20,20)` | 0（白噪声） | 1（随机常数） |
| `Noise(20,20)` | `Q_rclk_bds`（极大） | 0.001 m²/h（微小漂移） |

> **原理**：小初始方差 = "我对 ISB 有先验信息"，ISB 被约束在标定值附近，
> 即使 BDS-2 仅 2-3 颗也不会与高度产生严重耦合。微小过程噪声允许 ISB
> 缓慢漂移以适应温度变化等因素。

### 方法六：使用 `calibrate_bds23_isb_fixed_grid.m` 自动扫固定值并推荐最优值

该脚本用于对 `settings.BIASES.bds23_isb_fixed_m` 进行网格搜索，自动运行多次 PPP，
比较每个 fixed 值对应的 H/N/E RMS 和目标函数 J，并输出推荐值。

脚本位置：`CODE/OTHERS/calibrate_bds23_isb_fixed_grid.m`

#### 6.1 交互方式（推荐）

```matlab
cd('D:\code\matlab\raPPPid\raPPPid\WORK');
calibrate_bds23_isb_fixed_grid
```

交互流程：
1. 先选择 `settings.mat`（可选 `WORK/settings.mat` 或历史结果目录内 `settings.mat`）
2. 选择一个或多个 OBS 文件
3. 设置参数（deviceName、PROC 基路径、fixedGrid、maxRMS 等）
4. 自动开始 sweep 并输出推荐结果

#### 6.2 非交互方式（批处理）

```matlab
report = calibrate_bds23_isb_fixed_grid( ...
   'settingsFile', 'D:/.../settings.mat', ...
   'obsFiles', {'D:/.../a.25o', 'D:/.../b.25o'}, ...
   'deviceName', 'K181', ...
   'fixedGrid', 0:0.05:1, ...
   'skipEpochs', 0, ...
   'maxRMS', [0.2 0.2 0.2], ...
   'useParallel', true, ...
   'interactive', false);
```

#### 6.3 关键参数说明

| 参数 | 含义 | 常用值 |
|---|---|---|
| `fixedGrid` | 固定 ISB 搜索网格（m） | `0:0.05:1` |
| `skipEpochs` | RMS 计算前丢弃历元数（全历元可设 0） | `0` 或 `300` |
| `maxRMS` | 可行性阈值 `[H N E]`（m） | `[0.2 0.2 0.2]` 或 `[Inf Inf Inf]` |
| `requireTrueReference` | 是否强制使用真实参考坐标 | `true` |
| `procName` | 输出目录基路径，自动附加 `ISBFIXED_<fixed>` 后缀 | `GREC-K70/K181/ISB_FIXED_CAL` |
| `useParallel` | 并行穷举开关（结果与串行一致，仅提速） | `true` |

#### 6.4 输出结果

脚本会在 `RESULTS/ISB_FIXED_CAL/<device>_<timestamp>/` 下生成：

| 文件 | 内容 |
|---|---|
| `session_best.csv` | 每会话最优 fixed 结果 |
| `grid_all.csv` | 全部网格点结果（含 `nUsed/nValid/ok/usedTrueReference/feasible`） |
| `summary.txt` | 推荐值、MAD、P10/P90、约束提示 |
| `report.mat` | 完整结构化结果 |
| `sweep_*.png` | RMS/J 随 fixed 变化曲线 |

#### 6.5 推荐值定义

- 每个会话先在可行点中选最小 J（若无可行点则在有效点中选最小 J）
- 全部会话的 `best_fixed_m` 取中位数得到 `Recommended ISB0`
- `MAD`、`P10`、`P90` 用于衡量跨会话稳定性（单会话时仅具形式意义）

#### 6.6 性能与注意事项

- 网格越密、数据越长，耗时越大；可启用 `useParallel=true` 提升速度
- 并行 worker 数决定并发数（例如 8 workers 同时评估 8 个 fixed 点）
- 若 `best_fixed_m` 命中网格边界，脚本会提示扩展搜索范围
- 若 `maxRMS` 约束过严，可能出现 `satisfyConstraints=0`（回退到有效点最小 J）

---

## 9. 验证步骤

处理完成后，按以下步骤验证功能是否正常工作：

### 步骤 1：检查 settings 是否生效

```matlab
% 在结果目录中加载 settings
load('RESULTS/<your_result>/settings.mat', 'settings');
disp(settings.BIASES.estimate_bds23_isb);   % 应输出 1
```

### 步骤 2：检查 settings_summary.txt

```
% 打开结果目录下的 settings_summary.txt
% 搜索 "BDS-2/BDS-3 ISB Estimation is enabled"
```

### 步骤 3：检查参数维度

```matlab
% 加载 storeData
load('RESULTS/<your_result>/data4plot.mat');
size(storeData.param, 2)    % 应为 20（而非 19）
```

### 步骤 4：查看 ISB 数值

```matlab
m2ns = 1e9 / 299792458;
dt_BDS_common = storeData.param(:, 14) * m2ns;  % BDS 公共钟差 [ns]
ISB_BDS3 = storeData.param(:, 20) * m2ns;       % BDS-3 ISB [ns]（即 param(20)）

% 统计
fprintf('ISB mean:   %.3f ns\n', mean(ISB_BDS3(ISB_BDS3~=0), 'omitnan'));
fprintf('ISB std:    %.3f ns\n', std(ISB_BDS3(ISB_BDS3~=0), 'omitnan'));
fprintf('ISB median: %.3f ns\n', median(ISB_BDS3(ISB_BDS3~=0), 'omitnan'));
```

---

## 10. 输出可视化

启用 `settings.PLOT.bds23_isb = true` 后，处理完成时会自动生成：

| 图形名称 | 内容 |
|---|---|
| **BDS-2/BDS-3 ISB Analysis** | 三合一图：(1) BDS-2 与 BDS-3 钟差时间序列；(2) ISB 时间序列 + 均值线；(3) ISB 直方图 + 统计量 |
| **Clock Plot**（已增强） | BDS-2 和 BDS-3 显示为独立子图 |
| **Receiver DCB Plot**（已增强） | BDS-2 和 BDS-3 DCB 分别显示 |
| **Stdev of Parameters**（已增强） | 新增 dt_BDS3、DCB_C3_12、DCB_C3_13 标准差曲线 |

---

## 11. 适用场景

| 场景 | 模式 | 是否推荐 | 原因 |
|---|---|---|---|
| 测量型接收机（BDS-2≥4 颗 + BDS-3） | free | **推荐** | BDS-2 卫星充足，ISB 几何可观测 |
| 高精度后处理（BDS-2+BDS-3 均衡） | free | **推荐** | 分离后可提升定位精度 |
| 智能手机 PPP（BDS-2 仅 2-3 颗） | free | **不推荐** | BDS-2 不足，ISB 不可观测，高度退化 ~1.5m |
| 智能手机 PPP（BDS-2 仅 2-3 颗） | **constrained** | **推荐** | 标定先验约束解决几何秩亏问题 |
| 智能手机 PPP（短时段 10–30 分钟） | **fixed** | **优先推荐** | 不新增 ISB 状态，通常比 constrained 更稳 |
| 测量型接收机（单 BDS-3 信号） | — | 不需要 | 若只有 BDS-3 卫星，无需分离 |
| 使用 Decoupled Clock Model | — | **不支持** | 当前实现仅适用于 ZD 模型 |

---

## 12. ⚠️ 已知限制：BDS-2 卫星不足时的高度退化

### 现象

在 BDS-2 卫星数较少（≤3 颗）的数据集（如智能手机）上启用 ISB 估计，
会导致**高程方向 RMS 恶化约 1.5m**（dH: 26cm → 152cm），而水平方向基本不变。

### 根因：几何可观测性不足

ISB 列（`isBDS3`，仅 BDS-3 为 1）与 BDS 公共钟差列（`isBDS`，全部 BDS 为 1）
高度相关（ρ > 0.85），因为 BDS-3 卫星占 BDS 总数的 75-85%。

这属于**设计矩阵近秩亏缺**问题：

```
A_isBDS  = [0 0 0 1 1 1 1 1 1 1 1 1]  (3 BDS-2 + 9 BDS-3)
A_isBDS3 = [0 0 0 0 0 0 1 1 1 1 1 1]  (9 BDS-3 only)
相关系数 = 9/√(12*9) ≈ 0.87
```

后果：
- ISB 与 BDS 钟差相互"抢信号"，两者精度均下降
- PPP 中固有的高度-钟差相关性使退化集中映射到高度分量
- **任何滤波器调参（白噪声/随机游走/常数）均无法改善** — 这是几何问题

### 已测试的无效修复方案

| 方案 | dH 结果 | 结论 |
|---|---|---|
| 白噪声 ISB | 152.12 cm | 基线 |
| adjPrep_ZD_iono_est 补初始化 | 152.09 cm | 无效 |
| 分离 BDS-2/3 OMC 中值 | 152.12 cm | 无效 |
| 重参数化（公共钟+ISB） | 152.12 cm | 数学等价 |
| 共享 DCB（22→20 参数） | 152.12 cm | 无效 |
| DCB 级随机游走 | 151.35 cm | 几乎无效 |
| 近常数模型（Transition=1, Noise=0.01） | 151.49 cm | 几乎无效 |

### 建议

- BDS-2 ≥ 4 颗时使用 **free** 模式
- 希望避免显式先验/固定值注入时使用 **split** 模式
- BDS-2 ≤ 3 颗时（智能手机）优先 **fixed**，其次 **constrained**（需先标定 ISB）
- 启用 ISB 时 GUI 会弹出警告提示，包含四种模式说明
- 标定脚本：`calibrate_bds23_isb.m`（位于 `CODE/OTHERS/`）

---

## 13. 注意事项

1. **向后兼容**：旧的 `settings.mat` 文件可正常加载，缺失字段会自动补默认值（`false`/`'free'`/`0`/`3.0`）
2. **开启后模糊度参数索引偏移**：浮点模糊度从 `param(20+)` 变为 `param(21+)`，这由 `Adjust.NO_PARAM` 动态控制，对用户透明
3. **ISB 模式**：
   - **free**（默认）：白噪声，复用 BDS 钟差滤波设置。需要充足 BDS-2 卫星。
   - **split**：独立 BDS-2/BDS-3 时钟参数化，不需要 `bds23_isb_prior_m`/`bds23_isb_fixed_m`。
   - **constrained**：随机常数 + 标定先验。初始值 = `bds23_isb_prior_m`，初始方差 = `bds23_isb_prior_sigma_m²`，
     Transition=1，Noise=0.001 m²/h。适用于 BDS-2 不足的场景。
   - **fixed**：固定改正，不估计 `param(20)` 状态。改正值 = `bds23_isb_fixed_m`，适用于短弧段弱几何。
4. **BDS-2 卫星不足时的建议**：优先 fixed（见第 8 节“方法五”），其次 constrained（见“方法四”），或禁用 ISB（见第 12 节）
5. **ISB 对高度的影响**：BDS 公共钟差列与 ISB 列高度相关（ρ≈0.85），
   constrained 模式通过先验约束打破这种相关性，避免高度退化

---

## 14. 修改文件列表

### 新建文件
- `CODE/COMMON/isBDS2sat.m` — BDS-2（C01–C18）卫星判断函数
- `CODE/COMMON/isBDS3sat.m` — BDS-3（C19–C62）卫星判断函数
- `CODE/VISUAL/vis_plotBDS23ISB.m` — ISB 分析三合一图
- `CODE/OTHERS/calibrate_bds23_isb.m` — ISB 标定辅助脚本（提取先验值 + 写入 settings.mat）

### GUI 控件
- `CODE/VISUAL/GUI/GUI_PPP.fig` — 新增 `checkbox_bds23_isb`（Adjustment/Filter 面板）和 `checkbox_plot_bds23_isb`（Single Plot 面板）
- `CODE/VISUAL/GUI/GUI_PPP.m` — 新增 `checkbox_bds23_isb_Callback`（含 free/split/constrained/fixed 联动逻辑）和 `checkbox_plot_bds23_isb_Callback`

### 常量与设置链
- `CODE/COMMON/DEF.m` — 新增 `NO_PARAM_ZD_BDS23=20`、`BDS2/3_PRN_MIN/MAX` 常量
- `CODE/READ/getSettingsFromGUI.m` — 新增 `settings.BIASES.estimate_bds23_isb`、`settings.BIASES.bds23_isb_fixed_m`、`settings.PLOT.bds23_isb`
- `CODE/VISUAL/GUI/setSettingsToGUI.m` — 回填 `checkbox_bds23_isb` 和 `checkbox_plot_bds23_isb`
- `CODE/READ/checkProcessingSettings.m` — 向后兼容默认值 + DCM 互斥校验
- `CODE/PROCESSING/settings2txt.m` — 输出 ISB 启用状态

### 处理核心
- `CODE/PROCESSING/initProcessing.m` — 动态 `Adjust.NO_PARAM`、初始化 `Epoch.bds2`/`Epoch.bds3`
- `CODE/PROCESSING/RINEX2Epoch.m` — 每历元设置 `Epoch.bds2`/`Epoch.bds3`
- `CODE/PROCESSING/RawSensor2Epoch.m` — 同上（智能手机路径）
- `CODE/PROCESSING/adjustmentPreparation_ZD.m` — 扩展 param_sigma、Noise、Transition（ISB 复用白噪声）
- `CODE/PROCESSING/adjPrep_ZD_iono_est.m` — 同上（电离层估计路径）
- `CODE/PROCESSING/Designmatrix_ZD.m` — BDS→BDS-2/BDS-3 列分裂
- `CODE/PROCESSING/Designmatrix_code_ZD.m` — 同上
- `CODE/PROCESSING/Designmatrix_code_doppler_ZD.m` — 同上
- `CODE/PROCESSING/modelErrorSources.m` — free/constrained 使用状态估计，fixed 使用固定改正，split 使用独立 BDS2/BDS3 时钟参数化
- `CODE/PROCESSING/getReceiverClockBiases.m` — 钟差按 free/split/constrained/fixed 分支赋值

### 可视化
- `CODE/VISUAL/vis_plotReceiverClock.m` — BDS-2/BDS-3 分开子图
- `CODE/VISUAL/vis_plotReceiverDCBs.m` — BDS-2/BDS-3 分开 DCB 曲线
- `CODE/VISUAL/covParaPlot.m` — BDS-3 钟差和 DCB 标准差曲线
- `CODE/VISUAL/SinglePlotting.m` — ISB 图触发入口
- `CODE/VISUAL/plotCovarianceAdjustment.m` — 参数 20-22 标签
