# README 精简验证

日期：2026-10-13

## 变更

- 根 README 从 384 行缩为 166 行，保留中英文导航、功能摘要、安装、快捷键、隐私、目录入口、构建与核心测试命令。
- 原生回归、Debug 预览和签名打包操作迁入 `docs/development.md`，并加入文档索引。
- 移除首页中的 UI 尺寸、详细权限排障和累积版本描述；使用细节指向现有使用教程，版本变更指向已有发布验证记录。

## 实际执行的检查

- 本地链接与语言锚点检查：通过（README、文档索引、开发指南，共 57 个本地链接）。
- Markdown 代码块闭合检查：通过。
- README 双语结构检查：通过，两种语言均为 8 个对应章节；构建和测试命令完全一致，正文链接目标对应。
- 运行 good-readme 与 agents-gen 的只读上下文检查脚本：通过。
- 核对 `project.yml`、`Packages/KulaCore/Package.swift`、`AgentRuntime/package.json`、`SettingsPreferences.swift` 及打包脚本，确认工程、环境要求、命令和默认快捷键来自实际配置。
- 检查迁移文档引用的回归脚本与 Swift 源文件存在：通过。
- `git diff --check`：通过。

本次只修改文档，没有运行应用构建、Swift / Runtime 测试或真实系统权限验收。AGENTS.md 保持不变：原有规则与 README 中保留的命令、打包入口仍一致。
