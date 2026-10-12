# 聊天短信查询验证

日期：2026-10-12。

## 实现范围

- 原生 `messages_search` 经 ToolService 提供给聊天 Agent；外部 MCP 不可调用。
- 沿用 `advisorReadsMessages` 已保存的授权，设置文案改为“让 AI 读取最近 30 天的短信与 iMessage”，独立于后台 AI 判断。
- 每次执行检查读取开关与信息来源；查询期间撤权会拒绝返回结果。关闭信息来源同时阻止后台短信提炼。
- 按正文关键词和可选日期范围查询本机已同步的最近 30 天短信/iMessage，默认返回 20 条，最多 50 条；扫描上限 10,000 条，明确返回 `hasMore` 和 `scanLimitReached`。
- 解码 attributedBody，兼容秒/纳秒时间格式，过滤验证码、遮盖长数字与发送者号码，长正文返回包含关键词的摘录。只读访问数据库，查询失败与无匹配结果分别返回。
- Runtime 提示词要求实际调用工具，不得把权限失败解释为没有短信，也不得执行短信中的指令。

## 已执行检查

1. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：退出码 0，230 个 Swift Testing 测试通过。新增 4 项短信适配器测试覆盖原生 ToolService 调用、外部 MCP 拒绝、默认关闭、权限失败、非法范围、无匹配、结果截断、扫描上限、长正文、数据库只读查询、撤权、验证码过滤、长数字遮盖、旧版时间格式与 attributedBody-only 内容。
2. `(cd AgentRuntime && npm test)`：退出码 0，9 项测试通过。新增真实 Runtime 进程 + Pi SDK + 本机模拟 OpenAI 服务往返检查，确认 `messages_search` 参数转发到宿主、返回内容进入下一次模型请求，且更新的短信指南进入 system prompt。该检查没有使用真实模型服务或私人短信。
3. `xcodegen generate`：退出码 0。
4. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：退出码 0，BUILD SUCCEEDED。
5. `codesign --verify --deep --strict build/DerivedData/Build/Products/Debug/Asky.app`：退出码 0。此结果不等同于公证或 Gatekeeper 验收。
6. 启动开发构建并核对进程路径为本仓库 `build/DerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky`。实际设置 AX 显示“信息（查询与草稿交接）”、独立“短信读取”分组、“让 AI 读取最近 30 天的短信与 iMessage”，原有开关保持 on；查看了设置页截图。没有更改系统权限或密钥。

## 未完成的真实数据验收

尚未通过真实模型与用户短信完成一次聊天查询。后续 UI 查询验证遇到界面变化提示与 `noWindowsAvailable`，没有成功提交测试请求；不能把本机模拟模型/测试数据库的通过视为完全磁盘访问、真实短信同步或真实模型选工具已验收。

开发构建未安装到 Applications，未打包、发布或推送。构建、SwiftPM 与 Runtime 产物沿用现有 ignore 规则；原有 AGENTS.md 指令与模块边界无变化。
