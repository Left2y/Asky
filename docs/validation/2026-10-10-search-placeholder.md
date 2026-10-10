# 搜索框聚焦隐藏 Placeholder

日期：2026-10-10。

## 实现

搜索输入的 prompt 复用现有 `@FocusState`：获得焦点时显示空字符串，失去焦点时恢复 `Search`。非空输入仍由 TextField 自动隐藏 prompt。保留辅助功能标签和现有输入、提交与键盘导航行为。

## 实际验证

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：116 项测试、23 个 suite 通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。Xcode 输出 CoreSimulator 版本不匹配警告，未影响 macOS 构建。
- `git diff --check`：通过。

未运行实际窗口交互或截图验收。核心测试不覆盖 SwiftUI 焦点视觉状态。

README 和 AGENTS.md 检查：此处为现有搜索框的局部显示修正，不影响开发命令、产品用法或持久开发规则，均保持不变。构建产物继续使用现有忽略规则。

## 实际窗口复核

用户反馈仍显示占位文案后，确认运行中为此前的旧进程 PID 24849。正常退出后重新打开 Debug 构建，新进程 PID 37005。通过 `orca computer` 触发 ⌥Space，读取搜索窗口的辅助功能状态和截图：空输入框获得焦点，光标可见，`Search` 不显示。现有代码修改生效，无需进一步修改输入实现。

本次只验证聚焦的空输入状态；未验证失焦状态或完整键盘导航流程。
