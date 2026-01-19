# raPPPid 周跳检测和权重计算说明

## 1. 多普勒周跳检测 (Doppler Shift Cycle Slip Detection)

### 1.1 原理概述

在 raPPPid 中，多普勒周跳检测使用几何平均方法预测相位观测值。核心公式位于 `CODE/OBSERVATIONS/cycleSlip_Doppler.m`：

```matlab
% 几何平均预测（使用正负符号）
L_pred = L_old + dt*sqrt(D_now.*D_old);      % 正向预测
L_pred_ = L_old - dt*sqrt(D_now.*D_old);     % 负向预测
L_diff = min([L_diff2; L_diff_2], [], 'omitnan');  % 取较小者
```

其中：
- `L_old`: 上一个历元的相位观测值
- `L_now`: 当前历元的相位观测值
- `D_old`: 上一个历元的多普勒观测值
- `D_now`: 当前历元的多普勒观测值
- `dt`: 历元间隔 [秒]

### 1.2 工作流程

1. **获取观测值**：从当前和上一个历元读取相位(L)和多普勒(D)观测值
2. **单位转换**：对于智能手机数据，需要将多普勒从 m/s 转换为 Hz
3. **预测相位**：使用几何平均方法预测当前历元的相位值
4. **计算差异**：比较预测值与实际观测值的差异
5. **检测周跳**：如果差异超过阈值 (`settings.OTHER.CS.D_threshold`)，标记为周跳

### 1.3 阈值参数

- **参数名称**：`settings.OTHER.CS.D_threshold`
- **默认值**：通过 GUI 设置，在 `CODE/VISUAL/GUI/GUI_PPP.m` 中初始化
- **单位**：cycles（周）
- **位置**：GUI → Models → Other Corrections → Cycle-Slip Detection → Doppler Shift

## 2. Code 和 Phase 的标准差计算

### 2.1 原理概述

标准差用于计算观测值协方差矩阵，影响加权最小二乘估计。实现在 `CODE/PROCESSING/createObsCovariance.m`。

### 2.2 Code 观测值的标准差

```matlab
% 从 GUI 读取标准差（米）
settings.ADJ.var_code = str2double(get(handles.edit_Std_CA_Code, 'String'))^2;

% 计算方差
P_code = settings.ADJ.var_code ./ P_fac;  % P_fac 是加权函数
```

### 2.3 Phase 观测值的标准差

```matlab
% 从 GUI 读取标准差（米）
settings.ADJ.var_phase = str2double(get(handles.edit_Std_Phase, 'String'))^2;

% 计算方差
P_phase = settings.ADJ.var_phase ./ P_fac;
```

### 2.4 默认值

位置：`CODE/COMMON/F.m`

```matlab
std_code = 0.300;    % Code 观测值标准差 [m]
std_phase = 0.002;   % Phase 观测值标准差 [m]
```

**特点**：
- Phase 观测值的标准差远小于 Code 观测值（通常为 1/100 或更小）
- 默认值适用于大多数大地测量设备
- 智能手机等低成本设备需要增大标准差

### 2.5 加权函数

加权基于卫星仰角和信噪比：

```matlab
P_fac = createWeights(Epoch, elev, settings);
```

影响因子包括：
- 仰角加权函数（Elevation weighting）
- SNR 加权函数
- 设置的权重值

## 3. 自动确定最优阈值的方法

### 3.1 当前状态

目前 raPPPid **没有自动确定阈值**的功能。所有阈值都通过 GUI 手动设置。

### 3.2 建议的自动阈值确定方法

#### 3.2.1 多普勒阈值 (`D_threshold`) 的自动确定

**方法1：基于观测值统计**
```matlab
% 伪代码
function optimal_thresh = auto_Doppler_threshold(storeData, percentile)
    % 1. 提取所有历元的 L_diff 数据
    all_diffs = storeData.cs_L1D1_diff(~isnan(storeData.cs_L1D1_diff) & ...
                                      storeData.cs_L1D1_diff > 0);
    
    % 2. 计算百分位数（例如 99.5%）
    optimal_thresh = prctile(all_diffs, percentile);
end
```

**方法2：基于多普勒质量**
```matlab
function optimal_thresh = auto_Doppler_threshold_from_quality(storeData)
    % 计算多普勒测量的标准差
    doppler_std = std(storeData.doppler, 'omitnan');
    
    % 阈值 = 3倍标准差
    optimal_thresh = 3 * doppler_std;
end
```

#### 3.2.2 Code/Phase 标准差的自动确定

**方法1：基于残差分析**
```matlab
function optimal_std = auto_std_from_residuals(code_residuals, phase_residuals)
    % Code 标准差
    code_std = std(code_residuals(:), 'omitnan');
    optimal_std_code = code_std;
    
    % Phase 标准差
    phase_std = std(phase_residuals(:), 'omitnan');
    optimal_std_phase = phase_std;
end
```

**方法2：基于观测值-计算值 (OMC) 分析**
```matlab
function optimal_std = auto_std_from_omc(Adjust)
    % 从 OMC 历史数据计算标准差
    code_omc_std = std(Adjust.code_omc(:), 'omitnan');
    phase_omc_std = std(Adjust.phase_omc(:), 'omitnan');
    
    optimal_std_code = code_omc_std;
    optimal_std_phase = phase_omc_std;
end
```

**方法3：基于 C/N0 和仰角自适应标准差**
```matlab
function adaptive_std = adaptive_std_from_quality(Epoch, SNR, elev)
    % Code 标准差随 SNR 和仰角变化
    base_std_code = 0.300;
    
    % 校正因子
    snr_factor = 1 ./ (1 + SNR/30);  % SNR 越低，标准差越大
    elev_factor = 1 ./ sin(elev*pi/180);  % 仰角越低，标准差越大
    
    adaptive_std = base_std_code * snr_factor * elev_factor;
end
```

### 3.3 实现自动阈值确定的步骤

**✓ 已完成！** 已创建自动推荐阈值函数。

raPPPid 现在包含自动阈值推荐功能：
- `CODE/OTHERS/autoRecommendThresholds.m` - 基础推荐函数
- `CODE/OTHERS/autoRecommendThresholdsAdvanced.m` - 高级推荐函数
- `CODE/OTHERS/example_autoRecommendThresholds.m` - 使用示例

#### 使用方法

**方法 1：从命令行调用**
```matlab
% 加载观测文件路径到 settings 结构
settings.INPUT.file_obs = 'DATA/OBS/your_file.obs';

% 获取自动推荐
[recommended_settings, quality_report] = autoRecommendThresholds(settings);

% 应用推荐值
settings.OTHER.CS.D_threshold = recommended_settings.OTHER.CS.D_threshold;
settings.ADJ.var_code = recommended_settings.ADJ.var_code;
settings.ADJ.var_phase = recommended_settings.ADJ.var_phase;
```

**方法 2：运行示例脚本**
```matlab
% 运行提供的示例
run('CODE/OTHERS/example_autoRecommendThresholds.m')
```

#### 推荐逻辑

函数基于以下因素自动推荐：
1. **设备类型检测**：根据接收机名称识别是否为大地测量级、导航级或智能手机
2. **观测间隔**：根据采样率调整 Doppler 阈值
3. **经验值**：基于常见配置的最佳实践

#### 推荐值范围

| 设备类型 | Doppler 阈值 [cy] | Code σ [m] | Phase σ [m] |
|---------|-------------------|------------|-------------|
| 大地测量级 | 0.5-2.0 | 0.250 | 0.001 |
| 导航级 | 1.0-3.0 | 0.500 | 0.003 |
| 智能手机 | 2.0-5.0 | 1.000 | 0.010 |

### 3.4 实用建议

**对于不同的 RINEX 文件**：

1. **先使用默认值处理**
2. **检查残差图** (`CODE/VISUAL/plotResiduals.m`)
3. **如果残差异常**：
   - Code 残差大 → 增大 Code 标准差
   - Phase 残差大 → 增大 Phase 标准差
   - 过多误检周跳 → 减小 Doppler 阈值
   - 遗漏真实周跳 → 增大 Doppler 阈值

4. **手动调整示例**：
   ```matlab
   % 高质量大地接收机
   settings.ADJ.var_code = 0.300^2;    % σ = 0.300 m
   settings.ADJ.var_phase = 0.002^2;   % σ = 0.002 m
   settings.OTHER.CS.D_threshold = 1.0;  % [cy]
   
   % 智能手机接收机
   settings.ADJ.var_code = 1.000^2;    % σ = 1.000 m
   settings.ADJ.var_phase = 0.010^2;   % σ = 0.010 m
   settings.OTHER.CS.D_threshold = 2.0;  % [cy]
   ```

## 4. 相关文件位置

### 4.1 周跳检测
- `CODE/OBSERVATIONS/cycleSlip_Doppler.m` - 多普勒周跳检测
- `CODE/OBSERVATIONS/cycleSlip.m` - 周跳检测主函数
- `CODE/OBSERVATIONS/cycleSlip_dL.m` - 频间相位差分检测
- `CODE/OBSERVATIONS/cycleSlip_TimeDifference.m` - 时间差分检测

### 4.2 权重和标准差
- `CODE/PROCESSING/createObsCovariance.m` - 协方差矩阵创建
- `CODE/PROCESSING/createWeights.m` - 权重函数
- `CODE/COMMON/F.m` - 默认标准差值
- `CODE/READ/getSettingsFromGUI.m` - 从GUI读取参数

### 4.3 可视化
- `CODE/VISUAL/vis_cs_Doppler.m` - 多普勒周跳可视化
- `CODE/VISUAL/plotResiduals.m` - 残差图

## 5. 参考

raPPPid Manual 和相关 GNSS 处理文献。建议查阅：
- Hofmann-Wellenhof et al., Global Positioning System (GNSS) 
- Borre & Akos, A Software-Defined GPS and Galileo Receiver
- Guo & Wang (2023): "RAIM-based cycle slip detection using Doppler and double difference"

---

**注意**：此文档基于 raPPPid v3.1 源代码分析。特定版本的具体实现可能会有差异。

