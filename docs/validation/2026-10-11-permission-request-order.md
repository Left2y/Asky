# 授权结果刷新与屏幕录制请求顺序

日期：2026-10-11。

## 修改

- 日历、提醒事项、通讯录、通知直接使用系统请求返回的 Boolean 更新授权结果，不丢弃同意结果后立即读取可能滞后的状态。
- 权限页面的后台刷新带版本号；用户请求开始后，已有异步读取不能覆盖新请求结果，请求过程中也不开始新的刷新。
- 保留旧权限条目清理、当前进程自动注册和拖拽兜底。屏幕录制注册改为 ScreenCaptureKit 的异步可共享内容枚举，等待回调后开放卡片及系统设置页；不启动截图或录制，不保存枚举结果。
- 准备阶段隐藏并禁用拖拽卡片，避免拖拽授权先完成、后台清理或系统请求随后发生。异步注册返回时重新检查会话和取消状态，关闭浮窗后不继续打开系统设置。

API 依据：[EventKit 授权回调](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents%28completion%3A%29)、[ScreenCaptureKit 内容枚举回调](https://developer.apple.com/documentation/screencapturekit/scshareablecontent/getexcludingdesktopwindows%28_%3Aonscreenwindowsonly%3Acompletionhandler%3A%29?language=objc)。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过，Swift Testing 共 173 项。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-settings-regression.py`：通过。运行真实 AppKit/SwiftUI 窗口，权限读写使用注入结果；覆盖日历请求结果即时更新、延迟旧状态不覆盖新结果、等待注册完成前不打开设置、准备中取消后不继续、原有重新授权与拖拽回归。
- 检查回归生成的拖拽卡片图片，布局正常。
- README 双语同步；AGENTS.md 无需变更，模块边界及构建命令未改变。

## 未验证

未操作真实 TCC 同意按钮，未验证真实屏幕录制系统提示在回调前关闭的系统行为；需手动复测首次授权和旧签名条目恢复。已安装并运行的应用未替换，本次没有打包、安装或发布。
