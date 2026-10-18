# 单位换算图标验证

将单位换算结果的线性模板图标替换为用户提供的蓝底白色双向箭头 PNG。原图直接复制，SHA-256 为 `fde5d6b27d35bb58d75c6144fcab5efa037dd876313042cd3a8464735e268acd`。

复用 `LauncherFunctionIcon`：24 pt 槽、20 pt 可见外框、4.5 pt 连续圆角；白色箭头高度按书签等图标的 60/99 比例归一。设计系统已同步。

实际执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 按 README 构建 MCPBridge、安装 AgentRuntime 依赖并执行 `npm run build` 后，在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：全部通过。首次运行缺少运行时产物，补齐后通过。
- 使用临时原生窗口预览程序加载实际 `LauncherView` 与构建后的 Assets.car，输入 `1km in cm`，确认首项为单位换算、显示 `100000 cm`。已检查浅色与深色实际窗口截图，蓝底白色箭头显示正确；截图位于本地忽略目录 `build/conversion-NSAppearanceNameAqua.png` 和 `build/conversion-NSAppearanceNameDarkAqua.png`。首次预览等待窗口初始化不足，增加等待后完成检查。

README: unchanged — 仅更换结果图标，不改变用法、命令或安装流程。

AGENTS.md: unchanged — 未改变架构边界、子项目或开发命令。

本次构建与预览产物、依赖目录均复用现有忽略规则；未替换已安装应用。
