# 启动器占位文字颜色

- 将启动器「搜索或输入你的任务」的颜色由 `ThemeColor.kTextSubtle` 改为现有 `ThemeColor.kTextSubtlest`，与剪贴板搜索等占位文字保持一致。
- 主题映射从 Light `black70` / Dark `white70` 改为 Light `black50` / Dark `white50`，不修改全局变量值。
- 已执行 `xcodegen generate`，成功。
- 已执行 README 中的 Debug `xcodebuild` 命令，结果 `BUILD SUCCEEDED`。
- 已在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，命令退出码为 0，各测试套件通过。
- 尝试打开新 Debug 构建并通过 Orca 检查实际窗口；进程存在，但未取得可见启动器窗口，因此本次不记视觉验收通过。
- README 与 AGENTS.md 检查后保持不变：仅复用颜色变量，无使用方式、开发命令或架构边界变化。
