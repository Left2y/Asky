# AI 操作确认入口与本机版本检查

日期：2026-10-12。

## 原因与处理

- 本机进程 PID 77967 从 `/Applications/Asky.app` 运行，Info.plist 版本为 0.0.16。用户截图符合改版前 `ConfirmationCenter` 的 SwiftUI 浮动面板。
- 当前源码中 AppModel 为 ToolService 注入唯一的 ConfirmationCenter presenter；插件、系统工具及外部 MCP 的写入确认共用此入口，已经采用带 Asky 图标的 NSAlert。没有发现单独的旧 AI 确认弹窗实现。
- 在 Debug 主应用加入 `--test-confirmations`，依次呈现飞书插件、日历、信息与外部 MCP 的模拟请求，不初始化业务模型、不执行工具，完成后退出。README 中英文同步预览命令。
- 已校验本地发布包 0.0.17 ZIP 的 SHA-256 与配套摘要一致，并验证解包后的代码签名；备份旧安装后以该发布包替换本机应用。

## 已执行验证

- `xcodegen generate` 通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build` 最终通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过。
- 直接运行新构建的主应用 `--test-confirmations`，通过 Orca computer-use 检查实际窗口。飞书、日历、信息的截图均显示 Asky 图标、系统标题、说明及双按钮；外部 MCP 的可访问性树确认使用同一系统对话框和按钮。
- 两轮模拟预览的进程输出均记录四项返回值，覆盖 approved 和 rejected。最后一项关闭后的工具截图失败，以进程退出与输出作为返回值证据。
- Debug 预览不依赖独立探针。未发起真实飞书、日历、信息或 MCP 写入，也未重新验证系统权限申请。

本机旧应用备份、发布包解包目录位于 `build/validation/confirmation-all-entrypoints/`，沿用现有 `build/` 忽略规则。

README: updated — 同步 Debug 预览命令。AGENTS.md: unchanged — 没有新增架构边界或持久开发规则。
