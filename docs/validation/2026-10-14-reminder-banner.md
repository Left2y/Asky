# 自绘提醒卡片预览

- 新增 `App/Sources/ReminderBanner.swift`：无边框 `.nonactivatingPanel`，`level = .statusBar`，跨桌面空间和全屏显示，弹出时不激活 App。卡片从右上角滑入，最多同时显示 3 张，多出的排队；悬停时暂停自动消失并显示关闭按钮。开启「减弱动态效果」后不播放动画。
- Debug 入口：启动参数 `--test-banner`，或菜单栏 › 预览提醒卡片。暂未接入 ProactiveReminders，正式提醒仍走系统通知。
- 已执行：`xcodegen generate`，Debug `xcodebuild` 结果为 `BUILD SUCCEEDED`。实际以 `--test-banner` 启动，`CGWindowList` 读到 2 个 layer 3 的 Asky 窗口；单窗口截图确认两张卡片的内容、按钮和阴影都正确。截图位于已忽略的 `build/reminder-banner/`。
- 第一版窗口高度为 0：先清空 `sizingOptions` 再量 `fittingSize` 导致，已改为先量后清空。系统 bordered 按钮在非 key 窗口里会变灰，已改用自绘按钮样式。
- 未验证：按钮点击、悬停暂停、多显示器、浅色外观；本次没有修改 KulaCore，未运行 `swift test`。

## 修复：卡片被裁切、没有滑入动画（同日）

- 原因：`NSWindow.animator().setFrameOrigin` 不是可动画属性，调用被直接忽略，窗口一直停在起点（目标位置右移 40pt），卡片因此被屏幕右边缘裁掉，也没有动画。
- 改法：窗口直接放到最终位置，卡片内容在窗口里用 SwiftUI `offset` 从右侧滑入（弹簧动画），退出时滑回右侧。堆叠重排改用可以动画的 `animator().setFrame(_:display:)`。开启「减弱动态效果」时只做淡入淡出。
- 已执行：Debug `xcodebuild` 结果为 `BUILD SUCCEEDED`。启动后，窗口最终位置 X=-396、宽 408，所在屏幕的 visibleFrame.maxX=0，卡片右边缘离屏幕边缘 12pt，没有被裁切。连续截取第二张卡片的窗口，确认卡片从右向左滑入。

## 修复：滑入时带纵向移动（同日）

- 原因：内容先以 0 尺寸挂进窗口，随后再撑开到实际大小。这次布局变化和 `offset` 发生在同一次更新里，被 `.animation` 修饰符一起做成了动画，看起来就是「从右上角往下再往左」。另外，外阴影是一个单独的图层，滑动时跟不上玻璃，露出了黑边。
- 改法：先定好窗口的位置和尺寸，再挂内容，并立即完成一次布局。动画改为只用 `withAnimation` 包住 `presented` 一个值，不再用 `.animation` 修饰符。外阴影等滑入结束后再淡入。
- 已执行：Debug `xcodebuild` 结果为 `BUILD SUCCEEDED`。对第二张卡片的窗口连拍 10 帧，用不透明像素的范围测量卡片位置：上沿始终是 49–50px，下沿始终是 377–378px，左沿 696→351→197→100→71→…→47px，确认是纯水平滑入、缓出。
