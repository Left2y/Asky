# KulaHere 原生工具与 MCP 设计

更新日期：2026 年 10 月 9 日。状态：接口设计；系统适配器与签名下的权限行为待 M0 验证。

Launcher、Agent 与外部 MCP 共用 Swift ToolService。工具实现和权限策略只有一个归属主体：原生应用。模型、Pi 扩展和协议客户端不能绕过该服务。产品允许的操作以 [PRD](PRD.md) 为准。

## 调用路径

- Launcher 的确定性动作在应用内直接调用原生能力，不需要模型或 MCP。
- Pi 的工具调用通过受控宿主连接转交 ToolService，不直接执行 EventKit、AppleScript 或数据库读取。
- 外部 MCP 使用独立 Swift stdio Bridge，通过仅属主可访问的 Unix domain socket 连接运行中的应用（自用构建以 ad-hoc 签名，XPC 签名约束不可用；正式签名后可重新评估 XPC）；Bridge 不自行申请或持有系统数据访问权。
- 应用未运行时 MCP 返回可恢复的不可用状态；不会为了外部 MCP 启动 Pi，也不把 Bridge 变成 Launcher 的启动依赖。

本地连接隔离、实例凭据、签名与系统授权归属需要在真实构建中验证。独立协议入口不表示可以脱离原生权限主体运行。整体边界见 [框架](framework.md)。

## 工具接口契约

以下是实现必须覆盖的概念字段，不代表已经冻结的 Swift 类型或协议 JSON。

| 契约 | 必需内容 | 执行约束 |
| --- | --- | --- |
| ToolDefinition | 名称、描述、输入定义、数据源、读写效果、确认要求 | 同一登记驱动内部调用、允许列表和 MCP 暴露 |
| ActionRequest | 请求标识、工具、参数、任务关联、来源与用户意图 | 来源不能靠客户端自报名称获得权限；不能包含可信“已批准”声明 |
| ConfirmationRequest | 请求标识、目标、具体变更、必要说明 | 由原生层生成；确认仅对当前参数与目标有效 |
| ExecutionResult | 完成、拒绝、取消、失败或结果待核实；目标引用、实际结果 | 写入后回读；模型文本中的“成功”不能替代执行证据 |

具体参数 schema、工具名、版本、日期时间编码与错误码需在适配器验证后形成实现契约；首版应统一时区、重复事件、目标引用和不存在目标的语义，不能由每个入口自行解释。

## 系统适配器

| 能力 | 首选机制 | 范围与失败处理 |
| --- | --- | --- |
| 应用 | NSWorkspace | 名称与别名搜索、启动、切换；处理卸载或目标失效 |
| 文件 | Spotlight 元数据查询 | 首版文件名与路径，不建设全盘内容索引；范围受用户与系统权限限制 |
| Chrome | Chrome Apple Events 对象 | 仅普通窗口的标签标题、URL、窗口和标签标识；排除无痕，不注入网页 JS 或采集历史 |
| 计算、单位与汇率 | 本地受限解析、参考汇率缓存 | 不执行输入代码；ECB 日参考汇率显示日期，网络失败显示缓存或不可用 |
| 显式终端 | 用户提交的原生子进程 | 工作目录、stdout/stderr、取消、退出码；大输出落盘，交互命令交给终端 |
| Shortcuts | 系统快捷指令接口 | 参数、开始与结束状态；取消和错误如实反馈 |
| 剪贴板 | NSPasteboard | 文字与图片、敏感标记、排除、暂停；粘贴另行授权 |
| 日历、提醒事项 | EventKit | 查询和 PRD 允许的写入；处理只读目标、冲突、重复事件、时区与撤权 |
| 联系人 | Contacts | 姓名、已确认关系与联系方式；同名、多号码请求选择 |
| Notes | Notes Apple Events 对象 | 只在授权账户与文件夹搜索、读、新建和追加；无锁定内容、附件编辑或删除 |
| Messages | 草稿交接到 Messages | 验证收件人、Unicode 与预填；失败时复制正文并提示粘贴；最终人工发送 |
| 截图 | ScreenCaptureKit | 用户主动选择，单任务输入；取消、授权与临时清理 |
| 路线 | MapKit | 必要地点与交通偏好；缺条件或有效 ETA 时不给精确出发时间 |
| 通知 | UserNotifications | 无声交付、计划标识、去重、取消、时区与恢复校验 |

既有静态脚本定义检查记录包含 Notes 的正文与文件夹、Chrome 的标签页与窗口，以及 Messages 的发送命令；Messages 的该定义没有完整消息历史读取对象。静态定义只表明接口入口，不代表运行操作已验证。尤其 Notes、Chrome 与 Messages 应核实授权账户、目标状态、系统版本和真实执行结果。Messages 首版不读取历史消息，不调用发送命令。

官方依据：[EventKit](https://developer.apple.com/documentation/eventkit)、[Contacts 授权](https://developer.apple.com/documentation/contacts/accessing-the-contact-store)、[Apple Events 用途声明](https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription)、[ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)、[MapKit](https://developer.apple.com/documentation/mapkit)、[本地通知](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)。

## 权限与确认策略

系统权限、应用来源授权、允许 AI 使用、允许提炼、后台提醒以及外部 MCP 范围分别控制。系统授权通过不等于可以把该来源全部发给模型。

| 请求与操作 | 处理 |
| --- | --- |
| 应用内读取 | 校验启用来源和读取范围后执行 |
| 用户明确要求新建日程、提醒、备忘录 | 参数充分、目标可写、无未解决冲突时执行并回读 |
| 修改既有内容、删除或批量变更 | 展示目标和变更，再取得原生确认 |
| AI 推导出的新增系统写入 | 先展示建议，不能把模型建议当用户已要求 |
| 外部 MCP 读取 | 校验接入实例、凭据和分配范围 |
| 外部 MCP 写入 | 始终原生确认；内部新建规则不能用于外部调用 |
| Messages 交接 | 确认目标和草稿；外部调用需要原生确认；发送仍由用户在 Messages 完成 |
| AI 提议终端命令 | 展示命令与工作目录，获得该具体操作授权；不能借显式命令通道绕过 |

拒绝授权只关闭对应能力，不能循环弹窗。撤销权限、禁用来源或撤销 MCP 实例后，停止后续读取、清理待处理请求，并使未使用确认失效。外部内容作为数据，不能提高权限、改变允许列表或申请额外来源。

## 执行一致性

工具执行记录持久化请求标识、参数摘要、目标与状态，不依靠模型对话防重。写入串行；冲突或等待确认期间不能在后台悄悄执行其他关联变更。

超时或断线时不能直接重复创建。先回读系统目标或核对执行日志；结果不明则返回“待核实”。恢复只继续未完成、目标仍有效且仍获授权的操作。取消不会自动回滚已完成写入。

执行结果应包含可以验证的系统目标引用，界面提供查看入口。协议错误、系统拒绝、适配器失败、用户拒绝、取消和未知执行结果分别处理；原生结果不被模型二次改写为成功。

## 外部 MCP

首版使用自带的最小 stdio 实现（initialize、ping、tools/list、tools/call）。[官方 Swift MCP SDK](https://github.com/modelcontextprotocol/swift-sdk) 0.12.1 依赖 swift-nio，0.9.0 不能用 Swift 6.3 编译，SDK 可用后再评估是否替换。仅 stdio，本地使用，不开放远程网络服务。日志走 stderr，stdout 只传协议。

对外工具组限定为日历、提醒事项、Notes、联系人、Chrome 标签页和 Messages 草稿交接。默认关闭，启用实例默认只读，按实例分配数据源与操作范围。写入始终由应用确认，来源身份必须在本地连接与接入凭据上验证。

不公开完整个人记忆、剪贴板、API Key、任意 Shell 或直接发送短信。内部 Shortcuts、终端等能力也不能因为存在于 ToolService 就自动对外暴露。MCP 工具描述与 annotations 只能提供提示，实际策略由原生层执行。

M0 检查实例冒充、伪造确认、撤权、应用退出、多个连接、读写范围、取消、签名身份和权限提示归属。开发环境通过不能代替以后签名公证版本的验证。
