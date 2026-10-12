# 原生通知效果预览

- 增加 Debug 启动参数 `--test-notification`。通知由 Asky 进程通过 ToolService 发送，5 秒后交付，使用系统默认声音，提供“查看依据 / 已处理”操作；不创建真实日程或 ReminderPlan。
- 现有智能建议默认无声，Release 不触发测试入口。
- 已执行：KulaCore `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，退出码 0；`xcodegen generate`；Debug `xcodebuild`，`BUILD SUCCEEDED`。
- 实际启动本次新构建的 `build/SettingsStyleDerivedData/Build/Products/Debug/Asky.app --test-notification`；桌面截图确认右上角“会议即将开始”通知使用 Asky 图标，超过临时横幅时间后仍在。
- 系统设置 › 通知 › Asky 已从“临时”切成“持续”，并开启“播放通知的声音”；UI 读回和截图确认。实际听感未验证，操作按钮点击尚未验证。
- 构建日志、工作区基线与截图位于已忽略的 `build/notification-preview/`；截图 `desktop-final.png`。
- README 中英文同步增加测试命令与系统设置条件。AGENTS.md 检查后不改：现有 App / ToolService 边界与验证命令仍适用。
