# 如何使用自动推荐阈值功能

## 前提条件

1. ✅ 已创建 `autoRecommendThresholds.m` 函数
2. ✅ 已在 `GUI_PPP.m` 中添加回调函数
3. ✅ 你已设置观测文件

## 你的文件

**观测文件路径**：
```
D:\code\matlab\raPPPid\raPPPid\DATA\OBS\2025\218\cleaned2-K7new_gnss_log_2025_08_06_09_24_40-cc inconsistency.25o
```

## 使用步骤

### 步骤 1：打开 raPPPid GUI

```matlab
cd('D:\code\matlab\raPPPid\raPPPid')
run('raPPPid.m')
```

### 步骤 2：在 GUI 中设置观测文件

1. 点击菜单：**File → Set Input Files**
2. 在 "Observation File" 部分：
   - 点击 "..." 按钮
   - 选择你的文件：`cleaned2-K7new_gnss_log_2025_08_06_09_24_40-cc inconsistency.25o`
   - 确认路径显示正确

### 步骤 3：运行自动推荐

在 MATLAB 命令窗口输入：

```matlab
auto_recommend_thresholds()
```

或者：

```matlab
pushbutton_auto_recommend_thresholds_Callback(gcf, [], guidata(gcf))
```

### 步骤 4：查看推荐值

终端会显示类似如下：

```
==========================================================
  Auto-Recommend Thresholds (Quick Access)
==========================================================
✓ Found raPPPid GUI
✓ Got GUI handles

==========================================================
  Auto-Recommend Thresholds
==========================================================
Observation file: D:\code\...\cleaned2-K7new_gnss_log_2025_08_06_09_24_40-cc inconsistency.25o
Station: (your station)
Receiver: (your receiver)
Performing quick analysis...
Observation interval: 1.0 [s]
Detected device type: smartphone
  Doppler threshold: 2.00 [cycles]
  Code std dev: 1.000 [m]
  Phase std dev: 0.010 [m]

==========================================================
  RECOMMENDATIONS
==========================================================
Device Type: smartphone
Observation Interval: 1.0 [s]

--- Apply in GUI ---
1. Go to: Models → Other Corrections
   • Check "Doppler Shift"
   • Threshold: 2.00 [cycles]

2. Go to: Estimation → Weighting
   • Code: 1.000 [m]
   • Phase: 0.010 [m]
==========================================================
```

### 步骤 5：在 GUI 中应用推荐值

**A. 设置多普勒周跳检测**

1. 导航到：`Models → Other Corrections → Cycle-Slip Detection`
2. ✅ 勾选 **"Doppler Shift"**
3. 在 **"Threshold"** 输入框输入：`2.00`

**B. 设置权重**

1. 导航到：`Estimation → Weighting`
2. 在 **"Code"** 输入框输入：`1.000`
3. 在 **"Phase"** 输入框输入：`0.010`

**C. 其他推荐设置**

- **Processing → Elevation Mask**: `10` 度（智能手机建议）
- **Processing → SNR Mask**: `30` dBHz（智能手机建议）

### 步骤 6：开始处理

点击 **"Run"** 按钮开始处理。

## 预期推荐值

基于你的智能手机数据，预期推荐：

| 参数 | 推荐值 | 位置 |
|------|--------|------|
| Doppler 阈值 | 2.00 [cycles] | Models → Other Corrections |
| Code 标准差 | 1.000 [m] | Estimation → Weighting |
| Phase 标准差 | 0.010 [m] | Estimation → Weighting |
| 截止角 | 10 [度] | Processing |
| SNR 阈值 | 30 [dBHz] | Processing |

## 故障排除

### 问题 1：找不到 GUI

**错误**：`GUI not found`

**解决**：
```matlab
% 确认 GUI 已打开
run('raPPPid.m')
```

### 问题 2：找不到观测文件

**错误**：`Observation file not found`

**解决**：
- 在 GUI 中先设置观测文件
- 检查文件路径是否正确

### 问题 3：推荐函数出错

**错误**：`Error in autoRecommendThresholds`

**解决**：
- 检查 `CODE/OTHERS/autoRecommendThresholds.m` 文件是否存在
- 尝试用命令行直接调用：
  ```matlab
  addpath([pwd, '/CODE/OTHERS']);
  settings = getSettingsFromGUI(guidata(gcf));
  [rec, qual] = autoRecommendThresholds(settings);
  ```

## 命令行直接使用（无需 GUI）

```matlab
% 1. 准备设置
settings.INPUT.file_obs = 'D:\code\matlab\raPPPid\raPPPid\DATA\OBS\2025\218\cleaned2-K7new_gnss_log_2025_08_06_09_24_40-cc inconsistency.25o';
settings.INPUT.use_GPS = true;
settings.INPUT.use_GLO = false;
settings.INPUT.gps_freq = {'1F', '2W'};
settings.INPUT.rawDataAndroid = false;

% 2. 获取推荐
addpath([pwd, '/CODE/OTHERS']);
[rec, qual] = autoRecommendThresholds(settings);

% 3. 查看推荐值
fprintf('Doppler: %.2f [cycles]\n', rec.OTHER.CS.D_threshold);
fprintf('Code: %.3f [m]\n', sqrt(rec.ADJ.var_code));
fprintf('Phase: %.3f [m]\n', sqrt(rec.ADJ.var_phase));
```

## 快速参考

```matlab
% 最简用法
1. run('raPPPid.m')                    % 打开 GUI
2. 在 GUI 中设置观测文件
3. auto_recommend_thresholds()         % 运行推荐
4. 根据终端输出在 GUI 中输入推荐值
```

---

**提示**：推荐值已基于智能手机优化，可以直接使用。

