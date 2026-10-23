# 启动器功能插件验证

日期：2026-10-23。

## 实现范围

- 插件在既有 API v1 清单中声明 `commands`，注册 action 或 search 入口；兼容既有只声明工具的插件。
- 普通搜索按命令标题、触发词、插件名称发现入口；唯一且不冲突的触发词加空格进入输入模式。保留内置指令、网页指令及用户别名的优先级。
- action 按用户提交执行；search 只允许读工具，150 ms 防抖，取消旧查询并丢弃迟到结果。插件执行继续经过 ToolService 的确认、超时、回读与生命周期管理。
- 原生列表最多展示 200 项，提供复制和 HTTP/HTTPS 打开动作，显示插件提供的结果说明。插件可将工具设为 `agentVisible: false`，不依赖 AI 配置或 Agent 会话。
- 隐藏/退出清理临时结果；停用后不允许执行旧结果动作。写操作的原生确认不会因启动器失焦而提前取消或被外部点击遮罩拦截。
- `examples/plugins/text-tools` 提供 URL 编解码、Base64 编码和 UUID 生成；无 npm 依赖，不自动安装。

## 已执行检查

1. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：完整通过，共 303 项。另在独立源码快照中完整运行同一命令，303 项通过。
   - 新增 4 项 PluginLauncherTests：清单兼容性/参数与只读约束，结果数量/链接/唯一 ID，真实 Node worker 执行与安装启停卸载，以及启动器写命令的确认和回读。
   - 既有插件安装、更新、失败恢复、回退、配置与取消测试继续通过。
2. `xcodegen generate` 及 README 所列 Debug `xcodebuild`：通过。并行窗口功能正在修改共享源码，因此最终插件验证使用 `build/PluginSourceSnapshot` 中冻结的本次源码，DerivedData 位于 `build/PluginDerivedData`，不包含并行开发中的窗口扩展。
3. 在该快照根目录执行 `ASKY_DERIVED_DATA=/Users/niallyoung/orca/Asky/build/PluginDerivedData python3 App/Tests/run-launcher-window-regression.py --plugins`：浅色、深色原生回归通过。
   - 临时 LocalStore 中装入示例插件，不修改用户安装数据；不配置模型、不启动 AI。
   - 检查名称查找、选中入口、中文输入参数、关键词进入模式、UUID 动作、复制回读、取消旧查询、Esc 对应退出方法/空输入退格、隐藏清理、停用后旧动作拦截与入口刷新。
   - 检查写命令的确认队列、失焦保持和拒绝反馈。
   - 为避免其他并行 UI 回归注入事件，测试应用使用独立 bundle ID，并丢弃物理键鼠输入；通过实际 LauncherModel/LauncherController 驱动，不将其记为物理键盘 E2E 验收。
4. 已查看实际原生窗口浅色、深色截图：`build/PluginSourceSnapshot/build/plugin-launcher-NSAppearanceNameAqua.png` 与 `plugin-launcher-NSAppearanceNameDarkAqua.png`。
5. `python3 App/Tests/check-localization.py` 和 `git diff --check`：通过；README 两种语言的插件说明、插件协议、PRD、架构与测试命令同步。文档本地链接已检查。

## 边界

- 未发布或修改远端插件仓库；Orca/飞书现有版本仍按原 Agent 工具工作，需作者声明 commands 才出现启动器入口。
- 示例通过测试安装替身和真实插件 worker 验证；没有创建公开 GitHub 示例仓库或替用户安装插件。
- 本次没有修改 AgentRuntime TypeScript；验证复用了既有通用执行器。未重跑 npm test。
- 不提供自定义 HTML、任意窗口视图或全局后台搜索提供者接口；动态查询只在用户进入相应命令后执行。
- 构建产物、截图及冻结源码均复用现有 `build/` 忽略规则；AGENTS.md 沿用既有原生界面与 ToolService 边界，无新增指令规则。
