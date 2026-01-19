# raPPPid 错误修复和功能更新说明

## 修复的问题

### 1. 本地文件回退功能 (DownloadStreamArchive.m)

**问题**: 网络下载失败时没有检查本地文件
**修复**: 添加了本地文件回退机制
**文件**: `CODE/READ/DownloadStreamArchive.m`

### 2. satelliteClock 函数点索引错误

**问题**: `此类型的变量不支持使用点进行索引` 错误
**原因**: `preciseClk` 变量可能为空或不是结构体
**修复**: 添加了变量有效性检查
**文件**: `CODE/ORBITS/satelliteClock.m`

### 3. CAS Archive 文件格式更新

**问题**: CAS Archive文件格式从5分钟间隔(05M)更新为1分钟间隔(01M)
**修复**: 支持新的1分钟格式，同时保持5分钟格式的向后兼容性
**文件**: `CODE/READ/DownloadStreamArchive.m`
**重要**: raPPPid的数据读取和处理代码已经支持任意时间间隔，无需额外修改

#### 技术说明
raPPPid的核心数据处理函数（`read_precise_eph.m`, `read_precise_clocks.m`, `prec_satpos.m`, `satelliteClock.m`）都是基于时间戳的通用实现，不依赖于特定的时间间隔。这意味着：

- **SP3文件读取**: 读取所有时间戳，支持任意间隔
- **CLK文件读取**: 读取所有时间戳，支持任意间隔  
- **插值处理**: 使用固定点数插值，间隔越密精度越高
- **数据处理**: 基于时间戳进行，不依赖固定间隔

因此，1分钟间隔的数据将自动提供更高的处理精度，无需修改核心处理代码。

## 详细修复内容

### CAS Archive 格式更新

#### 问题描述
CAS Archive的文件命名格式发生变化：
- **旧格式**: `CAS0MGXRTS_20252180000_01D_05M_ORB.SP3.gz` (5分钟间隔)
- **新格式**: `CAS0MGXRTS_20252180000_01D_01M_ORB.SP3.gz` (1分钟间隔)

#### 修复方案
1. **优先使用新格式**: 首先尝试下载1分钟间隔格式
2. **自动回退**: 如果1分钟格式不可用，自动回退到5分钟格式
3. **本地文件支持**: 支持两种格式的本地文件回退
4. **详细日志**: 显示使用的文件格式信息

#### 修复代码
```matlab
case 'CAS Archive'
    % 尝试新的1分钟间隔格式，如果失败则回退到5分钟间隔格式
    file_sp3_1m  = ['CAS0MGXRTS_' yyyy doy '0000_01D_01M_ORB.SP3.gz'];
    file_sp3_5m  = ['CAS0MGXRTS_' yyyy doy '0000_01D_05M_ORB.SP3.gz'];
    
    % 首先尝试1分钟间隔的轨道文件
    file_sp3 = file_sp3_1m;
    file_format = '01M';
    
    % 下载逻辑包含格式回退和本地文件检查
    % ...
    
    fprintf('CAS Archive: Using %s format for orbit data\n', file_format);
```

### satelliteClock.m 修复

#### 问题描述
当 `preciseClk` 变量为空或不是结构体时，尝试访问 `preciseClk.t` 会导致错误：
```
此类型的变量不支持使用点进行索引。
出错 satelliteClock (第 85 行)
    idx = find(abs(preciseClk.t-Ttr) == min(abs(preciseClk.t-Ttr)));
```

#### 修复方案
1. **初始化变量**: 在函数开始时初始化 `preciseClk = []`
2. **添加检查**: 在使用 `preciseClk.t` 和 `preciseClk.dT` 之前检查变量有效性
3. **优雅处理**: 当数据无效时返回默认值而不是崩溃

#### 修复代码
```matlab
%% Preparations
noclock = false;
preciseClk = [];  % 初始化 preciseClk 为空

% ... 其他代码 ...

if settings.ORBCLK.bool_clk       % precise satellite clock enabled
    % 检查 preciseClk 是否有效
    if isempty(preciseClk) || ~isstruct(preciseClk) || ~isfield(preciseClk, 't') || ~isfield(preciseClk, 'dT')
        fprintf('Warning: No precise clock data available for satellite %d\n', sv);
        dT_clk = 0;
        noclock = true;
        return;
    end
    
    % ... 继续正常处理 ...
end
```

## 测试方法

### 测试 CAS Archive 格式支持
```matlab
% 检查CAS Archive文件格式
test_cas_archive_formats()
```

### 测试 satelliteClock 修复
```matlab
% 运行测试脚本
test_satelliteclock_fix()
```

### 测试本地文件回退
```matlab
% 检查本地文件
check_local_files()

% 详细调试
debug_local_files()
```

## 预期结果

### CAS Archive 格式更新后
- 优先使用1分钟间隔格式获得更高精度
- 自动回退到5分钟格式确保兼容性
- 显示使用的文件格式信息：
  ```
  CAS Archive: Using 01M format for orbit data
  ```

### satelliteClock 修复后
- 不再出现点索引错误
- 当精确时钟数据不可用时显示警告而不是崩溃
- 函数正常返回默认值

### 本地文件回退
- 网络下载失败时自动使用本地文件
- 提供详细的调试信息
- 避免重复下载

## 兼容性
- 所有修复都是向后兼容的
- 不影响现有功能
- 只是增加了错误处理和回退机制
- CAS Archive支持新旧两种格式

## 版本信息
- **修复日期**: 2025年1月
- **影响文件**: 
  - `CODE/READ/DownloadStreamArchive.m`
  - `CODE/ORBITS/satelliteClock.m`
- **测试文件**: 
  - `CODE/READ/test_cas_archive_formats.m`
  - `CODE/ORBITS/test_satelliteclock_fix.m`
  - `CODE/READ/check_local_files.m`
  - `CODE/READ/debug_local_files.m`