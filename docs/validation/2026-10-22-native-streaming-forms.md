# 原生流式表单试用版验证

日期：2026-10-22。范围：AI 回复内混排 Markdown 与 SwiftUI / AppKit 原生表单；没有 HTML 或 WebView。不是 Release 发布记录。

## 已运行的检查

| 检查 | 结果 |
| --- | --- |
| `xcodegen generate` | 成功生成工程 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build` | Debug 构建成功 |
| `codesign --verify --deep --strict build/DerivedData/Build/Products/Debug/Asky.app` | 通过 |
| `cd AgentRuntime && npm test` | 12 项通过，包含真实 Runtime / Pi SDK 与本地模拟 OpenAI 流之间的逐字段传输、完整回复及同会话回答继续 |
| `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | 各测试可执行文件合计 298 项通过 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ChatForm.swift App/Tests/ChatFormParserRegression.swift -o build/chat-form-parser-regression`，然后 `build/chat-form-parser-regression` | 每字符分片、关闭围栏前显示字段、未完整 JSON 隐藏、必填/选项/日期验证、重复 ID、未知类型、代码示例与未完成表单回退均通过 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --forms-preview` | 实际原生窗口回归通过，见下文 |
| `build/AgentReplyRegression.app/Contents/MacOS/AgentReplyRegression` | 既有澄清、完成时间、取消、消息持久化、附件及新会话回归通过 |
| `python3 App/Tests/check-localization.py` | 154 个 Swift 源文件检查通过；中英文键及参数一致 |
| `git diff --check` | 通过 |

原生窗口使用临时独立数据目录：先发出表单标题与首个字段，在仍流式生成时通过真实 NSTextField 编辑器输入，再追加字段；实际 NSPopUpButton 选择写回答案。完成消息替换流式内容后，同一个输入框实例、焦点和已填内容仍保留。文本、单选、多选和日期都显示在真实 AgentWindow 中。

提交检查初始化实际 AppModel / AgentHost，使用随机且不存在的测试凭据引用，使请求在凭据检查处结束，不调用真实模型。有效表单进入正常提交路径、保存到相同会话；原输入框草稿与附件保留，附件不随表单发送；连续点击被拒绝。重开历史后表单及文字回答存在，旧表单保持关闭。Runtime 的模拟模型测试单独验证后续回答确实继续原会话。

## 原生窗口视觉检查

已查看生成中的首字段、完整表单浅色/深色及窄窗口截图；字段、选择内容与提交按钮可读，未见横向溢出。初次检查发现深色原生选择器受聊天文字样式影响，已改用 AppKit 自行管理弹出按钮外观并重新回归。

- [字段仍在生成时输入](../../build/form-streaming.png)
- [完整浅色窗口](../../build/form-light.png)
- [完整深色窗口](../../build/form-dark.png)
- [窄窗口](../../build/form-narrow.png)

图片、日志及测试可执行文件在既有忽略规则 `build/` 下，不进入源码提交。

## 试用方式与限制

重启新构建的 Debug 应用，创建新对话，输入：“请用原生表单询问我的会议名称、时长、议题和日期，先不要创建日程。” 模型按内置指引输出 `asky-form` 行协议后，控件逐字段出现；生成期间可填写，回复结束后可提交。

这是按字段增量显示，不是显示半个 JSON 字段；无需额外模型调用或流式工具参数。真实提供商的首字段耗时和格式遵循率尚未验证，不能从本地模拟流推断真实响应速度。

当前每条回复最多一个表单。原始组件描述与已提交的可读回答随历史持久化；未提交值仅保留在当前打开的会话中，切换/重开后重新填写。更复杂的结果卡片、图表、动态联动字段、时间选择及跨重启表单草稿不在本次范围。未闭合表单不能提交，非法结构回退为普通代码；也始终允许输入框直接回答。

README 已同步中英文能力与实际检查命令。AGENTS.md 保持不变：没有新增独立子项目、系统访问边界或项目级开发政策。
