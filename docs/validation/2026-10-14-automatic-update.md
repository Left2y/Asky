# 自动更新

Date: 2026-10-14.

## 变更

- “设置 › 关于 Asky › 软件更新”新增“自动更新”开关（`SettingsPreferences.automaticUpdates`，默认开启，旧配置缺省时视为开启）。
- `ToolService` 将原 `prepareAppUpdate` 拆为 `stageAppUpdate`（下载、SHA-256 校验、解压、bundle identifier 与 `codesign` 校验，不动已安装应用）与 `installStagedAppUpdate(_:relaunch:)`（启动等待退出后替换的助手）。替换脚本新增第 5 个参数控制是否重新打开，并忽略 HUP/TERM，避免注销时中断两次改名。
- `App/Sources/AppUpdater.swift` 统一保存更新状态，“关于”页与后台共用：
  - 开启时启动 2 分钟后首次检查，之后每 6 小时检查；发现新版本即在后台静默下载并暂存，后台失败不打扰用户、下一周期重试。
  - 下载完成后不通知用户。满足“未在使用”时静默重启（`open -g`，不抢焦点）：启动器、剪贴板、AI 对话、设置窗口均未显示，无进行中 AI 任务、终端命令、待确认请求，外部 MCP 两分钟内无请求（`MCPLinkServer.isBusy(within:)`，仅空闲连接不算，桥接进程会自动重连）；并且屏幕锁定或屏保运行中，或 Asky 30 分钟未获得窗口焦点且系统 2 分钟无输入。锁屏、屏保启动、唤醒时立即判断，其余每分钟判断。
  - 已就绪但未重启时，“关于”页显示“将在你不使用 Asky 时自动完成更新”，可点“立即重启”；用户主动退出时（`AppModel.shutdown`）启动不重开的替换助手。
  - 暂存目录固定为 `~/Library/Caches/<bundle id>/Updates`；替换助手成功后删除旧版本与暂存目录，下次启动时清理中断更新的残留。
  - 源码构建（Info.plist 含 `KHSourceRoot`）或未安装到“应用程序”时不启动后台更新。
- 手动流程：检查更新 → 下载更新 → 立即重启（确认后替换并重新打开）。
- 新文案已加入 en / zh-Hans；用户指南与 PRIVACY.md 已同步。

## 已执行检查

```sh
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
python3 App/Tests/run-application-termination-regression.py
python3 App/Tests/run-settings-regression.py
plutil -lint App/Resources/*/Localizable.strings
```

- 核心包测试全部通过；Debug 构建通过。
- 新增 `requestsMarkServerBusyButIdleConnectionsDoNot`：MCP 请求期间与窗口期内视为忙碌，空闲连接不阻止重启。
- 终止回归通过，并新增“退出时安装”用例：替身进程退出后新包替换旧包、暂存目录删除，且未调用 `open`。
- 设置回归通过，`build/settings-{light,dark}-about.png` 中显示“自动更新”开关与说明。

## 未验证

- 未对真实 GitHub Release 执行端到端的后台下载、锁屏/空闲静默重启与退出替换；需在下一个发布版本安装后，用更高版本 Release 实测。
