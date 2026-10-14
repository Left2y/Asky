# 使用教程改为网站文档

日期：2026-10-14。变更仅涉及文档。

## 变更

- README 中英文的使用教程入口改为 https://asky.niallyoung2002.workers.dev/docs。
- 删除 `docs/user-guide.md`。该文件没有引用仅供其使用的图片；`docs/assets/demo.gif` 未改动。
- 文档索引与 `docs/data-and-memory.md` 中的教程链接改为同一网站地址，避免指向已删除文件。
- 核心能力「系统与扩展」中英文各补一句官方插件说明，链接到 [飞书](https://github.com/Niall-Young/asky-plugin-lark) 与 [Orca](https://github.com/Niall-Young/asky-plugin-orca)。飞书仓库由 GitHub 用户 Niall-Young 的公开仓库列表确认，描述为 Official Asky plugin for Lark/Feishu CLI workflows。

## 已执行检查

- 全文检索：除本记录与 2026-10-13 使用教程核查中对当时新增文件的历史描述外，没有指向 `user-guide.md` 的 Markdown 链接。
- Python 检查 README、文档索引与数据文档中的 43 个本地链接，目标均存在。
- `git diff --check` 通过。
- `git diff -- docs/assets/demo.gif` 为空。

本次没有修改 Swift、AgentRuntime 或 App，没有执行构建或运行时测试。
