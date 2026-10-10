# 附件输入框顶部间距

设计参照：[Figma 43:932](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=43-932)。本次读取了节点的设计上下文及截图：顶部 16 pt、附件和文本区间隔 12 pt、附件行水平内边距 20 pt、附件高度 52 pt。

原布局在外层 16 pt 顶部间距之外，叠加附件行 4 pt 内边距和卡片删除按钮 6 pt 预留空间，造成可见附件距顶部 26 pt。移除附件行的垂直内边距，附件状态外层顶部使用 10 pt，与卡片已有的 6 pt 预留空间共同构成 16 pt；附件行高度从 66 pt 调整为 58 pt，水平内边距对齐 20 pt。无附件时仍使用 16 pt 顶部间距。

实际执行并通过：

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：135 tests / 27 suites。
- `xcodegen generate`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 使用既有 `App/Tests/run-agent-reply-regression.py --attachment-preview <本次反馈图片路径>` 启动实际 SwiftUI 对话窗口，在临时数据库中通过原生文件选择器上传项目 README.md。窗口截图为 2×：输入框顶部约 y=896、附件顶部约 y=928，间距 32 px / 16 pt；输入框左侧 x=24、附件左侧 x=64，间距 40 px / 20 pt。截图保留于本地 `build/validation/composer-attachment-padding.png`，由已有 `build/` 规则忽略。

验证窗口已关闭，已打开本次构建的 Debug App。未发送模型请求。README 与 AGENTS.md 的现有命令、产品范围和边界未受此次间距修复影响，保持不变。
