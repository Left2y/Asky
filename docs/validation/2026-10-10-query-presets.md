# 仅保留查询预设与缩短 ChatGPT 关键词

日期：2026-10-10

- 依用户最终选择，默认入口仅保留 Google `go` 与 ChatGPT `chat`，两者支持携带查询。
- 一次性升级移除原样的 Gemini/豆包默认预设；将原样的 `chatgpt` 默认预设改为 `chat`。自定义配置不删除；已有 `chat` 关键词或应用/快捷指令别名占用时，不覆盖并保留原入口。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：145 项测试、28 个 suite 通过，覆盖移除预设、关键词迁移、重复迁移、别名冲突和 query 参数编码。测试首次因 Swift Testing 宏对 key path 的展开失败，改为闭包后通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 重启 Debug 产品检查设置 › 别名与快捷指令 › 网页关键词，可访问性树确认已存配置只显示 `go` 和 `chat`，Gemini/豆包不再显示；截图 `ac6d4342-2314-4ac5-97b3-49c3652f0405`（临时截图有时效）。未执行网站提交。
- README 中英说明及 PRD 已同步。AGENTS.md 无开发流程或架构边界变化，保持不变。沿用既有 build/ 与 SwiftPM .build 忽略规则；未打包或安装 Release。
