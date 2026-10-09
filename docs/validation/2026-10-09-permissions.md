# 系统权限请求与恢复入口

日期：2026-10-09。

## 问题与改动

- 日历与提醒事项工具此前只检查权限，首次使用并未请求；设置中的请求按钮忽略返回值与错误。
- ToolService 在来源/实例策略检查后、工具预览与执行前请求日历、提醒事项和通讯录权限。外部 MCP 不触发系统弹窗，需先在原生 App 授权。拒绝和系统限制不重复请求；仅首次请求或日历写入权限升级会弹窗。
- 授权期间来源若被关闭，返回后重新检查策略，阻止执行。并发权限请求合并，弹窗等待不计入工具执行超时。
- 设置新增独立“系统权限”页，显示日历、提醒事项、通讯录、屏幕录制、辅助功能、自动化与通知状态，以及逐项请求和打开系统设置入口。自动化按目标应用授权，不虚构统一授权状态；屏幕录制和辅助功能通过系统设置管理。
- AI 对话工具栏提供设置入口，权限或来源拒绝的工具行提供“管理权限”入口。授权后用户重新发送请求，不自动重放写入。

## 实际验证

- 在 `Packages/KulaCore` 中执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：106 项测试、22 个 suite 全部通过，包含新增 3 项权限门禁回归测试。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 构建输出有本机 iOS Simulator 版本不匹配和未依赖 AppIntents 的元数据提示，macOS 目标构建通过。

## 未验证

未操作真实授权弹窗或更改系统隐私设置。当前代码和构建通过不代表系统 TCC 已授予权限，既有运行进程也不会自动使用新构建。

需在新构建中检查首次日历授权、拒绝后跳转、系统授权后返回刷新、提醒事项与通讯录分别授权、Chrome/Notes 的自动化拒绝恢复，以及浅色/深色与键盘可访问性。首次访问前请求完全访问遵循 [Apple EventKit 文档](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents%28completion%3A%29)。
