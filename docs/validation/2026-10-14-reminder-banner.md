# 自绘提醒卡片预览

- 新增 `App/Sources/ReminderBanner.swift`：无边框 `.nonactivatingPanel`，`level = .statusBar`，跨桌面空间和全屏显示，弹出时不激活 App。卡片从右上角滑入，最多同时显示 3 张，多出的排队；悬停时暂停自动消失并显示关闭按钮。开启「减弱动态效果」后不播放动画。
- Debug 入口：启动参数 `--test-banner`，或菜单栏 › 预览提醒卡片。暂未接入 ProactiveReminders，正式提醒仍走系统通知。
- 已执行：`xcodegen generate`，Debug `xcodebuild` 结果为 `BUILD SUCCEEDED`。实际以 `--test-banner` 启动，`CGWindowList` 读到 2 个 layer 3 的 Asky 窗口；单窗口截图确认两张卡片的内容、按钮和阴影都正确。截图位于已忽略的 `build/reminder-banner/`。
- 第一版窗口高度为 0：先清空 `sizingOptions` 再量 `fittingSize` 导致，已改为先量后清空。系统 bordered 按钮在非 key 窗口里会变灰，已改用自绘按钮样式。
- 未验证：按钮点击、悬停暂停、多显示器、浅色外观；本次没有修改 KulaCore，未运行 `swift test`。
