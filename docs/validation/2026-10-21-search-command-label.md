# 搜索指令文案

- 将 `quickLinks` 入口的“搜索快捷方式”改为“搜索指令”，英文同步为“Search Commands”。保持命令 ID、触发词及图标不变。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，298 项测试。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --search-commands`：未通过，在 `SettingsRegression.swift:375` 断言中止，未产生本次截图，未完成视觉验收。
- `git diff --check`：通过。
- `AGENTS.md: unchanged`：文案修改不改变开发约定或架构。
- `README: unchanged`：文案修改不改变使用流程或开发命令。
- 本地构建产物由现有 `build/` 忽略规则覆盖，无新增忽略规则。
