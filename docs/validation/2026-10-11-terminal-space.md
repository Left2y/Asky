# 终端指令空格触发修复

日期：2026-10-11

## 行为

- 输入 `>` 保留普通搜索，按空格后才消耗指令并进入终端模式。
- `>pwd` 保持搜索，不生成终端执行动作；粘贴 `> pwd` 进入终端模式。
- 支持输入法全角空格；模式内保留 shell 引号、重定向；空输入退格退出。
- LauncherInputState 与 IntentRouter 共用带空白分隔符的终端匹配规则。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-launcher-terminal-regression.py`：通过。真实 NSTextView 先输入 `>` 再输入空格，验证模式、输入框内容与光标同步；同时验证退格、粘贴、shell 重定向及终端设置。
- 重启 Debug app（PID 32157），通过 Orca computer-use 输入 `>` 并按 Space，读取返回状态及查看两张截图：空格前保留 `>`，空格后清空输入并显示终端图标。
- 未执行终端命令交接测试（未传 `--handoff`）。

## 文档与 Git

- README 中英文及 PRD 同步空格触发规则。
- AGENTS.md：无需更改，未改变模块边界或开发命令。
- 本地构建与回归截图沿用已有 `build/` 忽略规则。
- 工作区原有其他未提交修改保持原样；README 仅提交本任务的终端说明。
