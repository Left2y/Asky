# 浮窗阴影改用系统原生

## 原因与修改

用户在 macOS 26.3.1 浅色模式下反馈：启动器呼出时先白色，随后闪成深色半透明，深色文字不可见，过一会儿恢复；另有一次表面变为灰色直角矩形。启动器与剪贴板此前在玻璃正下方绘制同形状的纯黑填充产生阴影，再用 `destinationOut` 挖空内部。挖空合成失败或滞后时，Regular 玻璃会叠在这块黑底上，与反馈的症状一致。

移除 `floatingSurfaceShadow` 自绘阴影，启动器（外壳与两个圆形按钮）和剪贴板主窗口统一启用 AppKit `hasShadow`，阴影形状与强度由窗口服务器按可见表面生成。原自绘方案用于模拟 Figma 中的投影参数，现不再追求逐项一致。

## 实际检查

- `swift test`（Packages/KulaCore）：通过。
- `xcodegen generate` 与 README 的 Debug `xcodebuild`：`BUILD SUCCEEDED`。
- macOS 27.0.1 视觉探针（生产 LauncherController / LauncherView，隔离临时数据）：浅色/深色模式，彩色与深色背景，空输入、单 AI 结果、输入后清空，桌面截图均显示沿外形的系统阴影，未见黑色外圈或底部双层轮廓。截图在已忽略的 `build/native-shadow/`。
- `run-launcher-window-regression.py`（LauncherWindowRegression.swift:542）与 `run-clipboard-regression.py`（ClipboardRegression.swift:331）均失败；在未修改的 HEAD 临时 worktree 中以相同位置、相同方式失败，属既有问题，本次未修复。
- 未在 macOS 26 实机复现或验证原问题，需要反馈用户在 26.3.1 上确认。
