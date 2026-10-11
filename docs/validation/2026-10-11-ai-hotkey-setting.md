# AI 对话自定义快捷键

日期：2026-10-11。

## 实现

- 在设置的“触发快捷键”页新增“AI 对话 / 打开 AI 对话”，复用现有原生快捷键录制控件，并提供恢复默认按钮。
- 默认组合键为 `⌃⌥⌘ /`（无需 Shift）；沿用开启空白新对话的行为。
- 组合键、修饰键和显示文本写入现有本地偏好；旧配置缺少这些字段时补默认值，保留既有外观、启动器和剪贴板设置。
- 应用启动时按保存的配置注册；修改时立即重新注册，注册失败不保存候选配置，并尝试恢复原绑定。

## 已运行检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore` 中）：退出码 0。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。环境仍有 CoreDevice/CoreSimulator 版本警告，没有阻止 macOS 构建。
- `python3 App/Tests/run-settings-regression.py`：成功，包含旧偏好解码、AI 自定义配置重新加载，以及原生设置页浅色/深色快照。
- 重启开发目录下的 Debug `Asky.app`，实际设置页可见“打开 AI 对话”、`⌃⌥⌘ / · 点击录制`、“已注册”与恢复默认按钮，已检查窗口截图。
- 实际应用设置窗口被其他操作持续切换，因此后续录制流程使用独立临时数据目录的原生预览进程：复用真实 SettingsView、HotKey、AgentWindowController，通过原生 UI 录制 `⌃⌥⇧⌘ T`，显示正确且已注册；再次按组合键打开 `Asky AI`，显示“新对话”和空白消息输入。关闭 AI 后点击恢复默认，显示恢复为 `⌃⌥⌘ /`。

## 验证边界

独立预览使用测试回调连接注册器与 AI 窗口，没有验证正式 AppDelegate 中自定义快捷键的完整端到端流程、冲突回滚或正在回复时的取消流程。未安装、打包或发布 Release；测试未发送模型请求。
