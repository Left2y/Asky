# 消息复制成功反馈

日期：2026-10-10

- 用户与助手消息共用复制按钮，ToolService 的 `MessageClipboard.copy` 返回成功后显示 16 pt 对勾。
- 成功状态持续 0.8 秒，再次成功复制生成新反馈 ID 并重启计时。SwiftUI task 在反馈变化或视图离开时取消；取消的旧任务不会清除新状态。
- 用户消息成功提示在鼠标移开后仍可见，到期恢复原有悬停显示规则。
- 复制失败不触发成功提示；成功状态的辅助功能标签为“已复制”。

## 已执行验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：133 tests / 27 suites 通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 退出旧进程并重开 Debug App，通过 Orca computer-use 打开已有对话，点击助手消息复制按钮；截图确认成功对勾，随后截图确认恢复原复制图标。
- 实际窗口验证覆盖助手消息的显示和恢复；连续点击计时、用户消息移出悬停及复制失败路径由代码检查，未声称已进行独立 UI 验收。

## 文档检查

- README 中英文同步 0.8 秒对勾与重复复制计时行为。
- AGENTS.md 无修改：此局部反馈不影响模块边界或开发命令。

## 缩短反馈时长后的复验

- 将停留时长由 3 秒缩短至 800 毫秒，用户与助手消息共用此计时逻辑。
- 默认 Command Line Tools 下的 `swift test` 因缺少 `Testing` 模块失败；改用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 后，135 tests / 27 suites 通过。
- `xcodegen generate` 与上述 Debug 构建命令通过，构建日志为 `BUILD SUCCEEDED`。
- 打开新构建的 Debug App，在现有对话点击助手复制按钮，截图确认对勾出现；随后截图确认恢复复制图标。800 毫秒精确时长由代码确认，截图未做逐帧计时。
