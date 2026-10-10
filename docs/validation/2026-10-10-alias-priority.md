# 别名匹配与快捷指令优先显示

## 变更

- 完整关键词（如 `go` / `GO`）无需尾随空格，即进入「别名匹配」结果组，位于最前并默认选中，显示关键词标签。
- 匹配项使用空查询的关键词 URL；不会将别名本身当作搜索正文。通用搜索动作仍按原规则展示，不算实际本地命中。
- macOS 快捷指令结果组在普通应用结果之前；存在别名时别名优先。
- `go SwiftUI` 继续进入关键词查询模式；不完整关键词不标记为别名。

## 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：133 tests / 27 suites 通过。
- `xcodegen generate` 和 README 的 Debug `xcodebuild`：通过。
- `python3 App/Tests/run-launcher-window-regression.py --alias-routing`：浅色与深色通过，覆盖大小写、延迟 provider 批次、默认选择、快捷指令前置、关键词查询和非精确输入。
- `python3 App/Tests/run-launcher-window-regression.py --ai-routing`：浅色与深色通过。
- 检查真实 LauncherModel / LauncherView / NSPanel 在隔离数据库和模拟搜索源中的浅色与深色渲染，确认「别名匹配」在首组，Google 行选中，关键词标签显示，快捷指令在应用之前。渲染输出在忽略的 `build/launcher-alias-*.png`。

## 验证范围

渲染检查使用真实原生窗口、模拟应用与快捷指令结果，没有执行真实搜索或快捷指令。GUI 自动化未能通过全局快捷键唤起实际 App 的搜索窗口，因此未声明实际个人数据搜索流程通过。未打包或安装 Release。
