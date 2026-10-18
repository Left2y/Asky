# 核心文案多语言补齐

## 修复范围

已修复[上一次检查](2026-10-18-localization-audit.md)列出的底层固定文案遗漏，覆盖日历、提醒事项、备忘录、联系人、短信、记忆、插件、系统权限、钥匙串、MCP、运行时协议、汇率与确定性提醒。

- `Contracts/CoreLocalization` 提供 App 与独立 MCP Bridge 共用的 310 个中英文资源键，通过 SwiftPM 打包 `KulaCore_Contracts.bundle`，不依赖 App 主 Bundle 中恰好存在翻译。
- 参数错误、授权失败、目标不存在、消歧、只读、冲突、保存失败、超时、取消和执行失败均在生成处使用本地化模板。工具说明和 schema 描述同步本地化。
- 明确处理 AppleScript 内部自定义错误、MCP 启动/连接/JSON-RPC 错误及运行时帧错误。
- 修复快捷指令状态直接展示 Swift 枚举调试描述的问题；运行、完成与失败提示按当前语言显示，输出保留原文。提醒预览的示例文案也已接入翻译。
- 原生 App 固定使用启动时的界面语言，设置语言仍在重启后生效；独立 Bridge 支持启动时的 `AppleLanguages` 或系统语言。
- 本地化检查覆盖 App、核心包与 Bridge 共 136 份 Swift 源码，并直接拦截 `ToolError`、失败结果及拒绝消息中未接入翻译的中文固定文案；检查全部资源的语言键、重复键和格式参数。
- 原生回归脚本统一复制共享资源包，普通 CLI 回归也复制到可执行文件旁。

## 保留的契约

错误码、工具名、字段名、ID、路径、输入别名、持久化结构及用户内容不翻译。确认请求的内部字段标记保持兼容，由已本地化的展示层解析。模型提示词、第三方原始错误和模型生成内容不进行整段替换。

更新了原先依赖中文词语的测试断言；例如工具轮数测试现在不会因为英文提示而一直等待。内存索引截断测试按实际本地化后缀计算上限。

## 验证

- `python3 App/Tests/check-localization.py`：通过，覆盖 136 份 Swift 源码及 App/共享资源表。
- Python 语法检查及检查器负例：通过，直接中文错误和多行失败返回会被识别，已本地化的错误不会误报。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，262 个 Swift Testing 测试、52 个 suite；新增独立资源包与内容保留测试。
- `cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`：通过。
- SwiftPM 独立 Bridge 与 App 内嵌 Bridge 均从 `/tmp` 启动，在 en、zh-Hans 下验证缺失凭据、连接失败和无工具名请求；启动退出码 64、JSON-RPC 错误码 -32603/-32602 保持不变，文案随语言变化。
- `xcodegen generate` 及 README 的 Debug `xcodebuild` 命令：通过；最终资源更新后重新构建亦通过。
- 原生英文、中文语言回归：通过，覆盖实际 ToolService 未知工具返回、无效插件路径、钥匙串错误、无效日程、共享资源包语言、语言改动不会改变当前运行语言、搜索入口和操作确认等既有回归。无真实日历或备忘录写入。
- `codesign --verify --deep --strict build/DerivedData/Build/Products/Debug/Asky.app`：通过。
- 原生内容快照对玻璃与 sheet 的合成内容捕获有限，不据此宣称所有窗口的视觉验收通过。

## 文档与工作区

README: updated；中英文同步共享资源与覆盖检查说明。AGENTS.md: unchanged；既有根规则和专题文档入口继续适用，检查由代码执行。

复用已有 `build/`、`.build/` 忽略规则保存构建和回归产物。保留原有未跟踪文件 `docs/validation/2026-10-18-icon-preview-app.md`。并行会话提交的玻璃修复 `dc77274` 保留，本次不更改其内容。
