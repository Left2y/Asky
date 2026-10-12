# Agent 免 Key 联网搜索

日期：2026-10-12

## 实现

新增 `web_search`，经 NativeTools → ToolService → AgentRuntime 工具转发执行 Bing 网页搜索。返回标题、真实来源链接、摘要、查询入口和检索时间；无需额外搜索 API Key，不使用模型厂商专有搜索接口。仅对 Agent/原生宿主开放，不对外部 MCP 开放。

设置 › 数据来源新增联网搜索开关，旧设置默认开启且不重置其他配置。网络请求使用临时会话，无浏览器 Cookie 或模型凭据；15 秒资源超时、1 MiB 响应上限，参数及结果数量有界。搜索结果为外部不可信摘要，模型规则要求引用来源、不执行网页指令，不把摘要当作全文，不把检索时间当作发布日期。

## 已执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ASKY_LIVE_WEB_SEARCH=1 swift test --package-path Packages/KulaCore`：208 项 Swift Testing 测试通过。覆盖源禁用、MCP 不开放、无效参数、重定向链接解码、实体、去重、数量上限、验证码和未知页面失败。
- `cd AgentRuntime && npm test`：8 项通过。新增真实 Pi Runtime 进程搭配本地模拟模型的搜索工具往返测试，确认工具目录、参数、来源结果和提示规则到达模型。
- 最终解析修订后 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ASKY_LIVE_WEB_SEARCH=1 swift test --package-path Packages/KulaCore --filter WebSearchTests`：5 项通过。
- 真实网络验收经 ToolService 的 Agent origin 提交 `Swift Apple documentation`，返回 5 条 Bing 结果，包括 `https://developer.apple.com/documentation/swift`、`https://docs.swift.org/latest/documentation/` 和 `https://developer.apple.com/swift/`。
- `xcodegen generate` 通过；`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/WebSearchDerivedData build` 通过，最终修订后再次构建通过。
- `git diff --check` 通过。生成物沿用已有 `build/`、`AgentRuntime/dist/`、`Packages/KulaCore/.build/` 忽略规则。

## 验收边界

Bing 网页搜索不是稳定的搜索 API；限流、验证和页面结构变化会明确失败，不能保证所有网络、地区或查询均可用。不读取结果网页全文。

新构建的 App 已启动，使用 Orca computer-use 按 PID 检查，但没有取得可操作的真实窗口，截图为黑色；本次启动的副本已退出，其他运行进程保留。设置开关的实际窗口及真实模型在原生对话中的自动搜索尚未验收。工具服务真实联网与 Runtime 模拟模型往返分别通过，不据此宣称原生对话已完成端到端验收。

README 中英文、工具文档和隐私政策已同步。AGENTS.md unchanged：仍使用已有 ToolService 边界、Swift/Node/Xcode 验证命令，无新增独立子项目或持久开发规则。工作区并行修改的提醒与信息相关文件不属于本次提交。
