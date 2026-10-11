# 设置窗口原生侧边栏

## 实现

- 使用 AppKit `NSSplitViewController`、sidebar 类型的 `NSSplitViewItem` 与原生 `NSToolbar`，左侧使用系统 sidebar 列表，右侧使用 SwiftUI grouped Form。
- 通用、外观、模型、快捷键、别名、网页关键词、数据来源、系统权限、记忆与外部 MCP 直接从侧边栏切换，移除顶部页签和二级分段导航。
- 配置项使用系统开关、弹出菜单、文本框与按钮。窗口初始内容尺寸 960 × 680，最小内容尺寸 820 × 560，可调整大小。
- `AppModel.openSettings(permissions: true)` 继续直接定位系统权限；主题应用于整个 AppKit 窗口。

## 实际执行

1. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：通过，退出码 0。
2. `xcodegen generate`：通过。
3. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/SettingsDerivedData build`：通过，`BUILD SUCCEEDED`。
4. 设置回归：通过，输出 `Settings native light/dark snapshots passed`。覆盖 10 个页面的浅色与深色渲染、页面标题跟随选择、权限恢复入口及最小窗口尺寸下侧边栏与详情宽度。

默认 DerivedData 被并行构建占用，因此使用独立构建目录。回归脚本显式选择 Xcode 的 macOS SDK，修复编译时自动选择 26.5 SDK、依赖模块却来自 27 SDK 的不一致。工作区另有并行源码修改，最终回归从 `build/settings-validation-snapshot` 中的源码快照运行：

```sh
KULAHERE_DERIVED_DATA=/Users/niallyoung/orca/KulaHere/build/SettingsDerivedData python3 build/settings-validation-snapshot/App/Tests/run-settings-regression.py
```

构建日志：`build/settings-sidebar-build.log`。回归日志：`build/settings-sidebar-regression.log`。所有本地验证产物由现有 `build/` 忽略规则覆盖。

## 原生窗口检查

运行使用临时 AppModel 数据目录、与正式 App 共用 `SettingsWindow.make` 的原生验证窗口，使用 Orca computer-use 截取真实合成窗口，并检查浅色通用页面、深色外观和模型页面，以及侧边栏点击后的选中状态与标题。

```sh
build/settings-validation-snapshot/build/SettingsRegression.app/Contents/MacOS/SettingsRegression --preview
build/settings-validation-snapshot/build/SettingsRegression.app/Contents/MacOS/SettingsRegression --preview --dark
```

实际窗口截图：`build/settings-native-light.png`、`build/settings-native-dark.png`。回归缓存截图用于详情渲染检查，不能捕获完整的原生侧边栏合成效果；侧边栏外观以真实窗口截图为准。

本次未执行模型保存、真实权限授权或系统数据写入；验证窗口使用临时配置。未打包或安装 Release。
