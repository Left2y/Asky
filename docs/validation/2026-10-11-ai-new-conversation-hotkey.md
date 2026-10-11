# AI 新对话快捷键

- 新增全局 `⌃⌥⌘ ?`（标准键盘 `Ctrl + Option + Command + Shift + /`）。直接展示 AI 窗口、隐藏启动器/剪贴板，清空草稿、附件和当前会话内容，保留历史；历史页返回对话页。
- 回复进行中先请求取消并等待旧事件流结束，再切换会话。此分支已构建检查，未使用真实模型验收取消流程。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（KulaCore）通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk python3 App/Tests/run-agent-reply-regression.py` 通过；首次未指定 SDKROOT 时发现 SDK 26.5/27.0 不一致，显式指定构建 SDK 后通过。
- README 的独立 HotKeyRegression 编译与执行通过（多快捷键共存、替换、注销）。
- 使用 computer-use 操作新启动的 Debug App（pid 12707），真实窗口回读确认快捷键打开 `KulaHere AI`，显示“新对话”和空白消息输入；设置测试草稿、进入历史页，再次触发快捷键后回读确认空白新对话且发送按钮禁用。未提交模型请求。
- README 中英文同步快捷键与取消行为；AGENTS.md 无持久规则变化。
