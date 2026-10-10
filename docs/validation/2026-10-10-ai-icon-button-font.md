# AI 页面 icon button 字号

- 顶部历史/返回、新对话、置顶、关闭按钮的 SF Symbols 字号由 17 改为 14 pt。
- 消息复制成功的 checkmark 由 16 改为 14 pt；附件删除 xmark 由 12 改为 14 pt。
- 附件选择与发送/停止图标原本已为 14 pt。保留全部按钮 frame、padding、圆角和交互行为；复制按钮的 ChatCopy 图片资源保持原样。
- 历史搜索图标及附件内容图标不属于 icon button，保持原字号。

## 实际验证

- 默认工具链执行 `swift test` 因缺少 Testing 模块失败；指定 Xcode 工具链后通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：140 tests / 28 suites 通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `git diff --check`：通过。
- 源码差异确认仅修改三个 font size，按钮布局参数未变；未进行运行窗口视觉验收。

README 与 AGENTS.md 无需调整：此次仅改变 AI 页面的图标字号，未改变使用流程、命令或架构边界。
