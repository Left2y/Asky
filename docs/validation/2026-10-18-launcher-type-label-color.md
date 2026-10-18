# 搜索结果类型文字颜色

- 结果行右侧类型文字从 `ThemeColor.kTextSubtle` 改为 `ThemeColor.kTextSubtlest`，复用现有 Light 黑色 50% / Dark 白色 50% 变量。
- `xcodegen generate` 通过。默认构建目录被另一构建占用，改用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/TypeLabelDerivedData build`，构建通过。
- `ASKY_DERIVED_DATA=/Users/niallyoung/orca/Asky/build/DerivedData DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --compact-results` 通过；该脚本重新编译当前 App 源码。已查看浅色和深色实际窗口截图，类型文字层级已减弱，长标题截断与行布局正常。截图位于忽略的 `build/launcher-compact-NSAppearanceNameAqua.png` 与 `build/launcher-compact-NSAppearanceNameDarkAqua.png`。
- `cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` 通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 未全通过：构建 MCPBridge 后，AgentHostTests 的 `unreachableModelFailsAndProcessIsGone` 仍有两项期望失败（`.running` 状态和 `runningPID`），位于 `RealRuntimeIntegrationTests.swift:37,39`。本次仅改 App 文本颜色，未修改这些逻辑。完整日志在忽略的 `build/type-label-core-tests.log`。
- README 与 AGENTS.md 无需更新：现有变量使用调整不改变使用方式、命令或架构约束。已有图标圆角及设计系统改动保留。
