# 网页指令默认启用范围

新配置仅开启 `go`、`chat`、`dy`、`tb`、`jd`、`bl`、`gh`、`x`。`ds`、`yt`、`bd`、`hb`、`zh`、`xhs`、`wb` 默认关闭，仍可在设置中开启。

缺少 `disabledBuiltInCommands` 字段的旧配置使用同一默认值；已有显式启停配置（包括表示全部开启的空集合）保留。README 中英文与 PRD 已同步。

## 已执行检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：280 项通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/CommandDefaultsDerivedData build`：`BUILD SUCCEEDED`。

- `ASKY_DERIVED_DATA="$PWD/build/CommandDefaultsDerivedData" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --website-commands`：通过；覆盖恰好八个默认开启指令、七个默认关闭指令、缺失字段回填、已保存空集合与自定义配置保留，以及启停、触发词持久化和输入路由。

本次使用独立的 `build/CommandDefaultsDerivedData`，日志与临时产物沿用既有 `build/` 忽略规则。
