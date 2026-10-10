# AI 回复标题与正文排版

日期：2026-10-10。

提示词要求回复使用 Markdown，最多一层标题，需要时统一用 `###`，禁止其他级别与嵌套标题，简短回复无需标题。此约束直接发送给模型，不改写或过滤回复原文。

实时及历史回复共用 ChatMarkdownView：六种标题标记均使用 16/500/Paragraph 样式；正文使用 14/400/Paragraph。行高目标分别为 32 pt 与 28 pt，复用 Theme.TextStyle 的行高表及现有 ThemedText 的自然字体行高近似补偿方式；实际行距受字体度量影响，不将行高当文字框固定高度。

## 已运行验证

- KulaCore `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：135 tests / 27 suites 通过。
- AgentRuntime `npm test`：4 tests 通过；现有真实 Runtime + mock 模型链路新增断言，确认单层标题规则被发送到模型 system message。
- `xcodegen generate`：成功。
- Debug `xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`（设置 DEVELOPER_DIR）：BUILD SUCCEEDED。
- 实际 ChatMarkdownView 的 NSHostingView 离屏渲染：浅色与深色截图，覆盖六级标题、中文自动换行正文、列表、引用、代码和表格。临时脚本与截图保留在 /tmp，不纳入版本库。

未重启当前 App、未发送真实模型请求；模型是否遵守格式要求仍需实际回复验收。新提示词在下一次 Runtime 启动时加载。README 中英文已同步样式；AGENTS.md 未改变，没有新增开发命令或模块边界。
