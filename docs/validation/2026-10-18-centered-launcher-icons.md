# 功能图标内部留白与视觉中心

修正只统一外框、未统一符号占比的问题。按原图白色符号测量，书签、链接、电源高度分别为 68、62、66 px；将三者归一到源图 60/99 的高度比例。按各自符号重心微调偏移，底板仍为 20 pt，图标槽仍为 24 pt，圆角仍为 4.5 pt。使用原图对应的实色填充缩放后露出的底板区域，原始 PNG 不变。

## 实际验证

- `xcodegen generate` 与 README 的 Debug `xcodebuild`：通过。
- `Packages/KulaCore` 的 `swift test`：262 项通过。
- 从实际源码提取 `LauncherFunctionIcon`，用 SwiftUI ImageRenderer 检查深浅背景及 24/48 pt 视觉效果：`build/centered-launcher-icons-preview.png`，检查符号占比、留白、居中及底板拼接。
- 重新编译临时原生窗口回归，排序、范围和深浅色窗口截图：通过。完整退出确认未复测，前次 `QuitSheetMissing` 限制不变。

README 不变：使用方式与功能描述未变。设计系统同步符号归一规则；AGENTS.md 不变：没有新增开发命令或架构约定。临时程序和截图沿用 `build/` 忽略规则。未替换已安装应用。
