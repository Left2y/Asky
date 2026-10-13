# 使用教程文档核查

日期：2026-10-13。变更仅涉及文档。

## 变更

- 新增 `docs/user-guide.md`，按安装、搜索、指令、计算、剪贴板、AI、系统来源、记忆提醒、扩展及常见问题组织用户操作步骤。
- README 的中英文快速开始均加入同一份中文教程入口，英文入口明确标注教程语言。
- 文档索引顶部及文档表加入使用教程，区分用户阅读与开发阅读。

## 已执行检查

- 对照当前 `SettingsPreferences.swift` 核对三个默认快捷键。
- 对照 `SettingsView.swift`、`SettingsWindow.swift`、`AliasSettings.swift`、`PermissionSettings.swift` 核对设置页面、按钮名称、模型检查、备忘录授权、记忆与 MCP 操作。
- 对照 `ClipboardWindow.swift`、`AgentView.swift` 与 `Keywords.swift` 核对复制/粘贴、固定记录、附件按钮及固定网页指令。
- 对照 README 和 0.0.19 发布记录核对安装方式、发布包适用平台与更新流程。
- Python 内联检查通过：README、文档索引与教程共 60 个本地链接目标存在；三份文档的页内锚点与代码围栏有效；README 保留中英文切换，两种语言均有教程入口。
- `git diff --check` 通过。
- 运行 agents-gen 与 good-readme 的只读仓库检查脚本；现有项目指引覆盖各独立子项目，新教程不改变开发命令、架构边界或持久指引。

本次没有修改 Swift、AgentRuntime 或 App，没有执行构建或运行时测试，也没有重新验收真实系统权限、模型服务及应用内升级。上述检查证明文档与仓库证据相符，不代表完成了这些实机验收。

README: updated，中英文同步教程入口。
AGENTS.md: unchanged，新增用户教程没有引入新的开发或架构规则。

未生成本地构建或测试产物，无需新增忽略规则。
