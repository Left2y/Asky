# 插件设置展示列表与添加对话框验证

日期：2026-10-23。

## 实现

- 移除页面顶部的内联安装表单。「添加」按钮并入搜索与分类 Tab 的同一行，打开窗口内玻璃对话框；对话框填写公开 GitHub HTTPS 仓库根目录链接，并在同一处说明插件会在本机执行代码，确认后直接安装。
- 每个分类合并为一张插件展示列表，替换原先「官方插件」「已安装插件」两张表及官方插件的重复行。官方插件无论是否安装都直接展示并带「官方」标签：未安装显示「安装」，安装后原地变为启用开关和更多菜单；自行安装的插件继续标注来源。
- 官方插件的安装按钮仍使用「安装可信插件」确认框；「添加」对话框已包含同样的信任说明，不再叠加第二个确认框。
- 搜索时按分类显示展示列表，官方目录项与已安装项按名称、仓库、工具、命令和触发词匹配；清除搜索恢复当前 Tab。
- 分类、安装、启停、配置、更新、回退和卸载继续使用原 PluginManager 与 PluginSettingsCategory。新增「添加插件」中英文文案。

## 实际检查

- `xcodegen generate` 与 README 所列 Debug `xcodebuild`：通过。共享工作区包含并行的窗口发现改动，未修改这些文件。
- `ASKY_DERIVED_DATA=/Users/niallyoung/orca/Asky/build/DerivedData python3 App/Tests/run-settings-regression.py --plugin-tabs -AppleLanguages '(zh-Hans)'`：通过。
- 同一命令以 `-AppleLanguages '(en)'` 运行：通过。英文对话框标题、中文原版标签换行问题在 520 pt 对话框宽度与单行标签后修复。
- 原生回归新增覆盖：未安装官方插件在 AI 类各显示一个安装按钮；已安装官方插件占用原目录行并取代安装按钮（只保留另一个官方插件的安装按钮）；「添加」按钮打开含仓库输入框的对话框并可取消；空功能分类保留唯一「添加」按钮。
- 已查看真实窗口截图 `build/plugin-tabs-zh-Hans-ai-light.png`、`plugin-tabs-zh-Hans-official-installed.png`、`plugin-tabs-zh-Hans-function-empty.png`、`plugin-tabs-zh-Hans-global-search.png`，以及用 `screencapture -l` 捕获的 `plugin-tabs-zh-Hans-add-dialog-light.png`、`plugin-tabs-zh-Hans-add-dialog-dark.png`、`plugin-tabs-en-add-dialog-light.png`、`plugin-tabs-en-add-dialog-dark.png`。确认官方标签、安装/开关互换、搜索分组与对话框标签单行显示。
- 窗口内对话框是玻璃表面，`cacheDisplay` 不合成玻璃，因此对话框截图改用真实窗口捕获。
- 启动 Debug 构建的真实应用并使用现有数据（Orca 0.2.0、飞书 0.1.0 均已安装）检查插件页：合并列表各显示一行，带「官方」标签与启用开关；「添加」对话框的仓库标签保持单行。截图：`build/plugin-settings-real-list.png`、`build/plugin-settings-real-add-dialog.png`。
- `python3 App/Tests/check-localization.py`：通过，158 个 Swift 源码文件。

## 范围

没有安装、卸载或修改用户已有插件，也没有访问远端插件仓库；未做真实 GitHub 安装验收。`添加` 对话框中的链接校验沿用 `PluginManager.repositoryURL`，未修改安装与执行代码。
