# AI 与剪贴板列表窗口宽度

按用户要求，仅统一宽度。AI 初始窗口和剪贴板列表窗口共用 `WindowMetrics.launcherWidth`，与启动器搜索栏一致，为 640 pt。AI 仍可手动调整窗口大小，剪贴板卡片模式维持原尺寸。

实际执行：

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过，日志 `build/window-width-build.log`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，日志 `build/window-width-swift-test.log`。首次未指定 Xcode 的运行因缺少 Testing 模块失败，切换完整 Xcode 后通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过，覆盖布局切换、筛选、选择、复制与持久化。检查了生成的 `build/clipboard-layout-list-image.png`，截图尺寸为 1280 × 1120 像素，对应 640 × 560 pt，图片与详情显示正常。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --preview`：打开实际 AI 窗口，Orca accessibility 读回宽 640、高 640 pt；检查实际窗口截图，标题、回复与输入区排版正常。检查后关闭本次预览进程。

README: unchanged — 小范围尺寸修正，不改变安装、命令或使用流程；具体尺寸已同步设计系统。

AGENTS.md: unchanged — 无新增命令、模块或持久架构约束。

本次日志与截图沿用已有 `build/` 忽略规则。原有未跟踪验证记录 `2026-10-18-debug-build-1707.md` 保留，不包含在本次提交中。
