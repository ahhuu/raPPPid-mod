# 自动阈值推荐功能 (Auto-Recommend Thresholds)

## 概述

`autoRecommendThresholds` 是 raPPPid 的一个**可选功能**，可以自动分析观测文件并推荐最适合的阈值设置。

## 核心功能

根据观测文件的设备类型和采样率，自动推荐：
1. **Doppler 周跳检测阈值** (`settings.OTHER.CS.D_threshold`)
2. **Code 观测值标准差** (`settings.ADJ.var_code`)
3. **Phase 观测值标准差** (`settings.ADJ.var_phase`)

## 文件列表

- `autoRecommendThresholds.m` - 基础自动推荐函数
- `autoRecommendThresholdsAdvanced.m` - 高级分析函数（预留扩展）
- `example_autoRecommendThresholds.m` - 使用示例
- `CYCLE_SLIP_AND_WEIGHTING_EXPLANATION.md` - 详细说明文档

## 快速开始

### 方法 1：直接运行示例

```matlab
cd CODE/OTHERS
run('example_autoRecommendThresholds.m')
```

### 方法 2：在命令行中使用

```matlab
% 准备 settings 结构（包含观测文件路径）
settings.INPUT.file_obs = 'DATA/OBS/your_obs_file.obs';

% 获取推荐
[recommended, report] = autoRecommendThresholds(settings);

% 查看推荐值
disp(recommended);
disp(report);
```

### 方法 3：应用到实际处理

```matlab
% 1. 获取推荐
settings.INPUT.file_obs = 'DATA/OBS/your_file.obs';
[recommended, ~] = autoRecommendThresholds(settings);

% 2. 应用推荐值
settings.OTHER.CS.D_threshold = recommended.OTHER.CS.D_threshold;
settings.ADJ.var_code = recommended.ADJ.var_code;
settings.ADJ.var_phase = recommended.ADJ.var_phase;

% 3. 继续处理
raPPPid_main(settings);  % 或其他处理函数
```

## 推荐值说明

### Doppler 周跳阈值

| 设备类型 | 1s 采样 | 5s 采样 | 30s 采样 | ≥60s 采样 |
|---------|---------|---------|----------|-----------|
| **大地测量级** | 0.5 cy | 1.0 cy | 2.0 cy | 3.0 cy |
| **导航级** | 1.0 cy | 2.0 cy | 3.0 cy | 5.0 cy |
| **智能手机** | 2.0 cy | 3.0 cy | 5.0 cy | 10.0 cy |

### 标准差推荐

| 设备类型 | Code σ | Phase σ |
|---------|---------|---------|
| **大地测量级** | 0.250 m | 0.001 m |
| **导航级** | 0.500 m | 0.003 m |
| **智能手机** | 1.000 m | 0.010 m |

## 设备类型识别

函数会自动识别设备类型：

**大地测量级接收机**（Geodetic）
- 包含关键词：geodetic, geod, choke, trimble, leica, novatel
- 特点：高精度、低噪声、稳定测量

**智能手机**（Smartphone）
- 包含关键词：android, smartphone, phone
- RINEX v0 (raw Android data)
- 特点：噪声较大、周期性跳变

**导航级接收机**（Navigation）
- 其他所有接收机
- 特点：中等精度、商业级设备

## 输出示例

```
=========================================================
  Automatic Threshold Recommendation
=========================================================
Station: YOUR_STATION
Receiver: Trimble NetR9

Performing quick analysis...
Observation interval: 1.0 [s]
Detected device type: Geodetic receiver
  Doppler threshold: 0.50 [cycles]
  Code std dev: 0.250 [m]
  Phase std dev: 0.001 [m]

--- Recommended Settings ---
Doppler CS threshold: 0.500 [cycles]
Code std dev: 0.250 [m]
Phase std dev: 0.001 [m]
=========================================================
```

## 手动调整建议

自动推荐是基于经验的初始值。实际使用中建议：

1. **先使用自动推荐值进行试处理**
2. **查看残差图**评估数据质量
3. **查看周跳检测图**评估周跳检测效果
4. **根据结果微调**：
   - Code 残差大 → 增大 `var_code`
   - Phase 残差大 → 增大 `var_phase`
   - 误检周跳多 → 减小 `D_threshold`
   - 遗漏真实周跳 → 增大 `D_threshold`

## 常用设备推荐值参考

### 高质量大地接收机
```matlab
settings.OTHER.CS.D_threshold = 0.5;
settings.ADJ.var_code = 0.250^2;   % σ = 0.250 m
settings.ADJ.var_phase = 0.001^2;  % σ = 0.001 m
```

### 标准导航接收机
```matlab
settings.OTHER.CS.D_threshold = 1.0;
settings.ADJ.var_code = 0.500^2;   % σ = 0.500 m
settings.ADJ.var_phase = 0.003^2;  % σ = 0.003 m
```

### 智能手机
```matlab
settings.OTHER.CS.D_threshold = 2.0;
settings.ADJ.var_code = 1.000^2;   % σ = 1.000 m
settings.ADJ.var_phase = 0.010^2;  % σ = 0.010 m
```

## 注意事项

1. **这不是强制性的**：函数是可选的，可以不使用
2. **建议仅作为起点**：自动推荐值应作为初始估计，可能需要手动微调
3. **需要有效的观测文件**：函数需要能正确读取 RINEX 文件头
4. **版本兼容性**：适用于 raPPPid v3.1+

## 故障排除

### 错误："Cannot read observation file"
- 检查文件路径是否正确
- 确认文件是有效的 RINEX 格式
- 检查文件权限

### 推荐值不适合
- 查看残差图，手动调整
- 参考 `CYCLE_SLIP_AND_WEIGHTING_EXPLANATION.md` 中第 3.4 节的建议

### 想要更精确的推荐
- 等待 `autoRecommendThresholdsAdvanced.m` 完整实现
- 手动运行 `AnalyzeObsFile.m` 进行详细分析

## 相关文档

- `CYCLE_SLIP_AND_WEIGHTING_EXPLANATION.md` - 详细的原理说明
- raPPPid 用户手册
- GNSS 处理最佳实践指南

---

**提示**：这是 raPPPid 的社区贡献功能。如有问题或建议，请联系开发团队。

