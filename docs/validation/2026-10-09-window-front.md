# AI 窗口前置与真实权限请求检查

日期：2026-10-09。

## 现场原因

用户截图仍显示旧日历失败文案，系统日历列表没有 KulaHere。运行进程 PID 1572 的启动时间为 17:50:18，磁盘上的 App 已在之后重建，运行的进程并未使用新的权限请求代码。退出旧进程并启动新构建后，权限页明确显示日历、提醒事项和通讯录“尚未请求”。

AI 窗口原先是普通层级（现场观察为 layer 0），未设置跨桌面/全屏辅助行为。

## 改动

- AI 与设置窗口使用浮动层级，并配置 `canJoinAllSpaces`、`canJoinAllApplications`、`fullScreenAuxiliary`。
- 前置 AI 窗口时先恢复最小化，再激活 App、设置 key window 并 `orderFrontRegardless`。
- 设置显示前隐藏启动器，避免启动器挡住设置。
- 再次从 Finder 打开已运行 App 时唤起 AI 窗口，不重新提交任务。

## 实际检查

- `xcodegen generate` 与带 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 的 README Debug `xcodebuild` 命令：成功。
- 核心包 `swift test`：106 项测试、22 个 suite 全部通过。
- 新构建启动后 PID 33624，启动时间 18:10:43；通过再次打开 App 成功显示 AI 窗口，工具栏中有“设置”按钮。
- 点击设置成功显示设置窗口，切换“系统权限”后成功看到各权限状态和独立请求按钮。
- 通过 `CGWindowListCopyWindowInfo` 只过滤 KulaHere 窗口观察，AI 与设置均在屏幕窗口列表中，layer 为 3（浮动层级）。
- 点击日历“请求授权”后，按钮显示“正在请求…”。系统 TCC 日志中的访问者和 subject 为 `app.kulahere.KulaHere`，请求由主 App 发起。

## 不能宣称通过的项目

系统授权界面 `com.apple.UserNotificationCenter` 被 computer-use 工具安全策略明确禁止操作；未点击系统“允许”，因此不宣称获得授权、系统列表已出现或真实日历写入成功。需要用户完成系统确认。

未实际切换全屏应用、Stage Manager 或多个桌面；这些场景的行为有对应代码配置和构建验证，但完整 UI 验收仍待进行。

该次构建期间其他任务提交了 Figma 启动器样式改动，本任务未修改或纳入那些文件。构建使用当时工作区源码，窗口前置改动独立提交。

窗口配置依据：[Apple canJoinAllApplications 文档](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications)。
