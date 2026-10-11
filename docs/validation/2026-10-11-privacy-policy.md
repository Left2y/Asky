# 隐私政策源码核查与发布待办

日期：2026-10-11。范围：当前工作树源码及文档静态核查；不是网络抓包、依赖完整安全审计或法律合规认证。

## 结论

已创建[隐私政策草案](../../PRIVACY.md)。重点是原版应用没有向作者上传用户使用数据的接口；本地读取、用户配置的模型服务、外部 MCP 客户端和主动提交支持材料分别说明。未修改产品代码，未运行 Swift/Node 测试、构建或真实界面验收。

## 当前源码依据

| 检查项 | 证据 | 结果与边界 |
| --- | --- | --- |
| 作者数据接收 / 遥测 | 检索 `App/Sources`、`Packages/KulaCore/Sources`、`AgentRuntime/src`、`MCPBridge/Sources` 的网络调用与 telemetry/analytics/sentry/upload 标记 | 未发现作者接收端、自动遥测或自动崩溃上报；不能据此宣称所有依赖和所有发行物已通过完整网络审计 |
| 模型接收方与凭据 | `App/Sources/SettingsView.swift`、`App/Sources/AppModel.swift`、`AgentRuntime/src/runtime.ts` | 使用用户配置的 baseURL；配置检查也会联网；Keychain 凭据交给本机运行时用于认证 |
| AI 上下文 | `App/Sources/AgentModel.swift` 的 `send`、`AgentRuntime/src/runtime.ts` 的 `composeInput`、`extensions/system-tools.ts` | 相关记忆、图片/文本附件、恢复会话与工具结果可能进入请求；不能写“仅发送当前一句话” |
| 默认剪贴板与过滤 | `App/Sources/AppModel.swift` 的 `AppSettings`、`ClipboardMonitor.swift`、`ToolService/ClipboardAccess.swift` | 默认开启，隐藏/临时标记和部分密码管理应用被排除；过滤并非通用敏感信息检测 |
| 保留规则 | `LocalStore/Repositories.swift` 的 `ClipboardStore` / `ActivityStore`、`AppModel.start` | 30 天规则在清理时执行；剪贴板有 200 MiB 预算，固定项保留；不能说所有数据 30 天自动删除 |
| 本地保存 | `LocalStore/Schema.swift`、`Database.swift`、`Keychain.swift`、`AppModel.makeAgentHost`、`AgentRuntime/src/main.ts` | KulaHere 目录、普通 SQLite/WAL、附件、runtime/agent/sessions 与追加的 runtime-stderr.log；钥匙串服务为 app.kulahere.credentials |
| 删除对话 | `AgentModel.delete`、`ConversationStore.delete`、`MemoryStore.deleteSource` | UI 删除不调用 Runtime 文件/附件删除或来源联动；不能承诺“删除对话彻底删除所有副本” |
| MCP 与其他联网 | `AppModel.refreshMCPServer`、`MCPLink`、`DirectActions/Currency.swift`、`Keywords.swift` | 本地 MCP 接入后结果交给客户端；汇率下载 ECB 公共表；网页打开由浏览器处理 |

## 正式发布前必须确认

1. 填入发布/处理主体、可用的隐私邮箱和生效日期。Niall-Young 是仓库维护标识，不能替代未经确认的主体信息。
2. 在应用中提供可访问的隐私政策入口，并在开始记录剪贴板、首次向模型发送数据及授权 MCP 时提供适合该行为的明确说明。当前本任务只添加文档，未实现这些 UI。
3. 检查实际分发包及完整依赖的网络行为，确认没有额外遥测、自动更新或其他接收端；发生变化时同步政策。
4. 补齐并验证删除对话时 Runtime 会话、附件、来源与派生记忆的处理；验证完整本机清理、凭据移除与正在运行任务的边界。当前政策如实披露限制。
5. 对当前没有期限的日志、会话和其他记录确定必要的保留上限，并验证清理；不要先在政策里承诺尚未实现的期限。
6. 若面向公众提供服务或涉及适用法律下的敏感信息/境外提供信息，按真实业务和接收方确认告知、同意及其他适用义务。BYOK、开源、系统授权和 MIT 许可均不自动豁免。

法律条文核对来源：[《中华人民共和国个人信息保护法》官方全文](https://www.cac.gov.cn/2021-08/20/c_1631050028355286.htm)，重点核对第十七条（告知）、第二十九条（敏感个人信息）、第三十八至三十九条（境外提供）、第四十四至四十七条（个人权利）。本草案未据此作出适用于所有地区的合规结论。

## 文档验证

- 已核对新增本地 Markdown 链接存在、README 中英文隐私摘要对应、代码块配对与 diff 空白检查。
- README 原有未提交的语言/构建说明改动保留；本次仅隔离隐私新增段落。
- AGENTS.md 维护检查：文档变动未改变模块边界、开发命令或独立子项目；保持不变。
