# 帮助教程与记忆说明同步

日期：2026 年 10 月 13 日。范围：仅文档更新，不修改 Swift、App 或 AgentRuntime。

## 修改内容

- 使用教程改为按当前仓库说明，移除旧版本号与已撤掉的记忆列表操作；补充文件入口、索引与主题、明确保存/纠正/忘记、自动提炼整理、暂停与删除、排错步骤。
- PRD、数据专题和架构中的记忆职责同步为 Markdown 文件方案；明确逐条来源、替代关系、删除联动等不能作为当前能力承诺。
- 隐私草案补充提炼整理的模型请求、整理副本与旧数据库迁移边界；README 中英文同步记忆能力与外发事实，文档索引更新导航说明。

## 核对依据

已阅读当前 `MemoryFolder.swift`、`MemoryExtractor.swift`、`MemoryConsolidator.swift`、原生记忆工具登记、`AgentModel.swift`、`MemorySettings`、`ProactiveReminders.swift` 与 Runtime 的 `personal-context.ts`：

- 对话上下文使用非空索引，主题按需读取；设置页为开关与访达入口。
- 提炼等待对话空闲至少 30 分钟，在一轮回复结束或新建对话时尝试；整理尝试至少间隔 6 小时。
- 自动记忆开关与个人记忆来源分别控制提炼整理和上下文/工具；后台 AI 判断为独立功能。
- 整理前保留最近一版 `.previous/`；显式忘记只删当前文件中的行；索引不存在可重新迁入旧版符合条件的记录。

## 实际执行的检查

- Python 文档检查通过：7 个修改文档中的 90 个本地链接与锚点均存在，代码围栏成对；README 中英文节数与 shell 命令一致，新记忆能力和外发事实人工比对一致。
- `git diff --check` 通过。
- README gate：updated，中文与英文同步记忆能力及外发说明。
- AGENTS.md gate：unchanged，文档同步没有改变开发命令、系统调用边界或独立子项目。

未运行 Swift/Runtime 测试、Xcode 构建或实机 UI/模型验收；本次只确认文档与源码行为对应，不新增功能验收结论。
