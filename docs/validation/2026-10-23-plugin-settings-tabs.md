# 插件设置分类与搜索验证

日期：2026-10-23。

## 实现

- 插件设置复用指令页的搜索框与原生分段 Picker，提供「AI 插件」「功能插件」两个 Tab。搜索框提取为共用 SettingsSearchField，指令页原有行为保留。
- 有可见 Agent 工具或指导文件的插件归入 AI 类；有 commands 的插件归入功能类；混合插件在两类中显示同一个安装记录。旧版没有 commands 的插件仍可在 AI 类管理。
- 官方与已安装列表按类别过滤；未安装的现有 Orca、飞书官方插件只属于 AI 类。没有功能插件时显示相应空状态，不将 Agent 插件伪装成功能入口。
- 搜索跨两类匹配名称、仓库、工具描述、命令与触发词；搜索时显示分类标题，无匹配时显示单一空状态，清除搜索回到选中的 Tab。
- 安装入口保持一处；代码按安装结果自动切换类别，混合插件优先切功能类。更新、回退、卸载、配置和启用继续使用原 PluginManager。

## 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：完整通过，日志共 307 项。
- `xcodegen generate` 和 README 所列 Debug `xcodebuild`：独立源码快照构建通过。共享工作区有并行的窗口发现改动，原工作区首轮构建遇到其新增类型尚未被工程发现；没有修改这些窗口代码，改用 `build/PluginTabsSourceSnapshot` 冻结已提交基线 56e5933 与本次文件，DerivedData 为 `build/PluginTabsDerivedData`。
- 快照根目录运行 `ASKY_DERIVED_DATA=/Users/niallyoung/orca/Asky/build/PluginTabsDerivedData python3 App/Tests/run-settings-regression.py --plugin-tabs -AppleLanguages '(zh-Hans)'`：通过。
- 同一编译产物运行 `build/SettingsRegression.app/Contents/MacOS/SettingsRegression --plugin-tabs -AppleLanguages '(en)'`：通过。
- 新原生回归使用独立临时 LocalStore，覆盖 AI/功能/混合分类、旧清单兼容、真实分段控件切换、混合插件开关持久化与跨 Tab 状态、命令触发词跨分类搜索、无匹配、清除搜索与没有功能插件的状态。通过 AppKit 原生控件驱动，并显示真实 SettingsWindow；为隔离其他 UI 回归的事件，测试丢弃物理键鼠输入，不记为物理键盘 E2E。
- 快照根目录运行 `ASKY_DERIVED_DATA=/Users/niallyoung/orca/Asky/build/PluginTabsDerivedData python3 App/Tests/run-settings-regression.py --command-layout`：通过，覆盖共用搜索框后的原指令 Tab、ql 名称、跨 Tab 搜索、无匹配和编辑焦点。
- 已查看真实窗口截图：`build/PluginTabsSourceSnapshot/build/plugin-tabs-zh-Hans-ai-dark.png`、`plugin-tabs-zh-Hans-function-light.png`、`plugin-tabs-en-function-light.png`；同目录保存两种语言的浅深色、全局搜索和空状态截图。
- `python3 App/Tests/check-localization.py`、`git diff --check` 和修改文档的本地链接检查通过。

## 范围

没有安装、卸载或修改用户已有插件，也没有访问远端插件仓库。安装完成自动选择类别已实现并审阅，未做真实 GitHub 安装验收。没有运行完整设置回归或 npm test，本次没有修改 AgentRuntime。

README 中英文、PRD、插件指南与开发命令已同步。AGENTS.md 现有设置组件与 ToolService 边界仍适用，无指令变更。源码快照、构建和图片沿用已有 build/ 忽略规则，无新增忽略项。
