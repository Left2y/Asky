# 剪贴板窗口 Pin 按钮修复

## 定位与改动

前一版误改了 AI 窗口标题栏；用户截图对应剪贴板窗口右上角的 Pin。剪贴板原实现将圆形背景放在 Button 外，且没有悬停状态。

本次将背景和 32×32 圆形 contentShape 一起放入 Button label，并以独立 View 的 onHover 状态绘制主题 InteractionHover。置顶与取消置顶同步更新辅助功能标签、值和提示。保留原有图标、尺寸和窗口置顶逻辑。

## 实际验证

- Xcode 工具链 `swiftc -frontend -parse App/Sources/ClipboardWindow.swift`：通过，仅语法解析。
- `git diff --check`：通过。
- `xcodegen generate`：通过。
- 核心 `swift test` 和 README 中的 Debug `xcodebuild`：均退出 69，Xcode 许可协议仍未接受。
- 没有启动修改后的窗口；整圈空白区域点击、悬停视觉和置顶切换仍待实际验收，不能记为通过。

README: unchanged — 小范围交互修复不改变使用方法或开发命令。
AGENTS.md: unchanged — 不改变持久工程约定或模块边界。
