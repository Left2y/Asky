# 数据来源 App 图标

数据来源九行在文字左侧显示 24×24 pt 图标，间距 8 pt。日历、提醒事项、备忘录、通讯录、Chrome、快捷指令、信息和地图通过 ToolService 按 Bundle ID 读取本机应用图标；个人记忆使用现有 AppIcon artwork 的 AskyLogo 图片资源。应用未安装时使用通用 App 图标。装饰图标对辅助功能隐藏，Toggle 标签和绑定保持原有行为。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：通过，19 tests / 4 suites。初次编译缺少 DataSourceID 的 terminal / clipboard 分支，补齐后重新运行通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，`BUILD SUCCEEDED`。
- `python3 App/Tests/run-settings-regression.py`：通过，`Settings native light/dark snapshots passed`。
- 已人工查看最新 `build/settings-light-sources.png` 和 `build/settings-dark-sources.png`：九项图标身份、对齐和浅深色显示正确，个人记忆为 Asky logo。截图来自运行中的原生 SettingsRegression 窗口；未检查已安装 Release 的窗口。

日志：`build/data-source-icons-tests.log`、`build/data-source-icons-build.log`、`build/data-source-icons-settings.log`。全部验证产物沿用现有 `build/` 忽略规则。未打包或安装 Release。

README: unchanged — 本次仅补充列表图标，使用流程、权限、开发命令不变。

AGENTS.md: unchanged — 仍遵循现有 ToolService 系统读取边界和验证命令，没有新增长期规则。
