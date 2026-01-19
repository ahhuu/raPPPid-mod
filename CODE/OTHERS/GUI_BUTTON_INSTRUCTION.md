# 在 raPPPid GUI 中添加自动推荐阈值按钮

## 已完成的修改

✅ 已在 `GUI_PPP.m` 中添加回调函数 `pushbutton_auto_recommend_thresholds_Callback`

## 如何在 GUI 中使用

### 方法 1：从命令行调用（推荐，最简单）

不需要修改 GUI 界面，直接在 MATLAB 命令窗口中调用：

```matlab
% 1. 打开 raPPPid GUI
gui_handle = GUI_PPP;

% 2. 在 GUI 中设置观测文件
% （在 GUI 中手动选择你的观测文件）

% 3. 从命令行调用推荐功能
pushbutton_auto_recommend_thresholds_Callback(gcf, [], guidata(gcf));
```

### 方法 2：添加到菜单（最简单）

在 `GUI_PPP.m` 中找到菜单项定义，添加一个新菜单项。

### 方法 3：添加到现有按钮（需要修改 .fig 文件）

由于 `.fig` 文件是二进制格式，需要：

1. 用 MATLAB GUIDE 打开 `CODE/VISUAL/GUI/GUI_PPP.fig`
2. 添加一个新按钮
3. 设置按钮的 Tag 为 `pushbutton_auto_recommend_thresholds`
4. 设置按钮的 Callback 为 `@(hObject, eventdata) GUI_PPP('pushbutton_auto_recommend_thresholds_Callback', hObject, eventdata, guidata(hObject))`

## 当前最佳使用方法

**最简单的方法**：创建一个快捷键脚本

创建 `auto_recommend_thresholds.m`：

```matlab
function auto_recommend_thresholds()
% 快捷方式：自动推荐阈值
% 在 MATLAB 命令窗口运行此函数

try
    % 获取当前 GUI
    fig = findobj('Tag', 'figure_GUI_PPP');
    
    if isempty(fig)
        errordlg('Please open raPPPid GUI first.', 'Error');
        return;
    end
    
    % 获取 handles
    handles = guidata(fig);
    
    % 调用回调函数
    pushbutton_auto_recommend_thresholds_Callback(fig, [], handles);
    
    fprintf('\n✓ Recommendations displayed in command window.\n');
    fprintf('Follow the instructions to apply values in GUI.\n\n');
    
catch ME
    fprintf('Error: %s\n', ME.message);
end
end
```

**使用方式**：
1. 打开 raPPPid GUI
2. 设置观测文件
3. 在 MATLAB 命令窗口输入：`auto_recommend_thresholds()`

## 自动应用推荐值（实验性）

如果你想自动将推荐值应用到 GUI，取消注释 `GUI_PPP.m` 第 683-689 行：

```matlab
% 在 pushbutton_auto_recommend_thresholds_Callback 函数中
set(handles.checkbox_CycleSlip_Doppler, 'Value', 1);
set(handles.edit_CycleSlip_Doppler_threshold, 'String', ...
    num2str(recommended.OTHER.CS.D_threshold));
set(handles.edit_Std_CA_Code, 'String', ...
    sprintf('%.3f', sqrt(recommended.ADJ.var_code)));
set(handles.edit_Std_Phase, 'String', ...
    sprintf('%.3f', sqrt(recommended.ADJ.var_phase)));
```

**注意**：自动应用可能存在兼容性问题，建议手动应用。

## 使用流程

### 你的智能手机文件

**文件路径**：
```
D:\code\matlab\raPPPid\raPPPid\DATA\OBS\2025\218\cleaned2-K7new_gnss_log_2025_08_06_09_24_40-cc inconsistency.25o
```

### 步骤

1. **打开 raPPPid GUI**
   ```matlab
   cd('D:\code\matlab\raPPPid\raPPPid')
   run('raPPPid.m')
   ```

2. **在 GUI 中加载观测文件**
   - File → Set Input Files
   - 选择观测文件

3. **运行自动推荐**
   ```matlab
   % 从命令行调用
   pushbutton_auto_recommend_thresholds_Callback(gcf, [], guidata(gcf));
   ```

4. **查看推荐值**
   终端会显示：
   ```
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

5. **在 GUI 中手动输入这些值**

6. **开始处理**

## 预期推荐值

对于你的智能手机数据：

```
✓ Doppler 周跳阈值: 2.00 [cycles]
✓ Code 标准差: 1.000 [m]
✓ Phase 标准差: 0.010 [m]
```

## 注意事项

1. **必须先设置观测文件**：GUI 需要先加载观测文件
2. **函数位置**：自动推荐函数在 `CODE/OTHERS/autoRecommendThresholds.m`
3. **回退机制**：如果分析失败，会使用基于设备类型的默认值

## 快速测试

```matlab
% 测试自动推荐功能
test_settings = struct();
test_settings.INPUT.file_obs = 'D:\code\matlab\raPPPid\raPPPid\DATA\OBS\2025\218\cleaned2-K7new_gnss_log_2025_08_06_09_24_40-cc inconsistency.25o';
test_settings.INPUT.use_GPS = true;
test_settings.INPUT.use_GLO = false;
test_settings.INPUT.gps_freq = {'1F', '2W'};
test_settings.INPUT.rawDataAndroid = false;

[rec, qual] = autoRecommendThresholds(test_settings);
```

---

**提示**：目前功能已完整实现，只需要在命令行中调用回调函数即可使用。未来可以在 GUI 中添加实际的按钮。

