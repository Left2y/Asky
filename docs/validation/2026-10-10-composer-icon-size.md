# AI 输入框底部图标字号

- 附件按钮的 paperclip 图标由 17 pt 改为 14 pt。
- 发送／停止按钮的 arrow.up / stop.fill 图标由 16 pt 改为 14 pt，保留 medium 字重。
- 两个按钮继续使用 32 × 32 pt 区域，行为保持不变。

## 验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：135 项测试通过。
- 首次未指定 DEVELOPER_DIR 的 `swift test` 因 Command Line Tools 缺少 Testing 模块失败，切换到 Xcode 后通过。
- `git diff --check`：通过。
- 未进行运行中窗口的视觉验收；旧进程需重新打开 Debug 构建后显示新字号。

README 与 AGENTS.md 检查结果为 unchanged：本次仅调整图标字号，开发命令、产品用法和模块边界未变化。
