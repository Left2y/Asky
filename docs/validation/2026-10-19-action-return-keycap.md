# 搜索与剪贴板回车键提示统一

剪贴板列表底栏的回车提示从 `↩` 改为搜索使用的 `↵`；无粘贴目标时的复制提示同步为 `⌘ ↵`。两处继续复用 `LauncherActionKeyCap`，不改变按钮布局或快捷键行为。

已执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 中执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：退出码 0。
- `git diff --check`：通过。

本次核对了搜索与剪贴板的字符及共享键帽组件，未运行实际窗口视觉验收。

README: unchanged：仅修复提示字符，不改变使用方式或开发命令。
AGENTS.md: unchanged：不涉及持久开发规则或模块边界。
