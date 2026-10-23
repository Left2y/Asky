# 设置分类标签圆角统一

日期：2026-10-23。

## 问题

指令设置与插件设置顶部的分类切换沿用系统分段控件，在 macOS 26 上渲染为完整胶囊；同一行的搜索框、按钮与卡片都是 8 pt 普通圆角，因此该切换显得突兀。

## 实现

- 实测 macOS 26：`NSSegmentedControl` 的 `automatic`、`rounded`、`texturedRounded`、`roundRect`、`separated`、`capsule` 六种 `segmentStyle` 位图完全一致，均为胶囊，原生样式无法改小圆角。
- 新增共享 `SettingsSegmentedControl`（`SegmentedTabsView`）：外框复用 `settingsInputChrome` 的底色、1 pt 边框与 8 pt 圆角，内距 2 pt；选中段 6 pt 圆角、系统强调色底与白字，每段宽度按 14 pt 标题实测值加左右各 12 pt。
- 指令设置（搜索指令／内置指令）与插件设置（AI 插件／功能插件）的分类切换改用该控件；日程编辑器弹出层的系统分段控件不在本次范围。
- 控件内部仍是原生 `NSButton`，保留键盘焦点、按下与辅助功能 radio button 语义；回归可直接用 `performClick` 与 `state` 驱动。
- 顺带修正插件添加对话框回归：SwiftUI 将带样式的 prompt 写入 `placeholderAttributedString`，查找时同时接受两种占位符表示。

## 实际检查

- `xcodegen generate` 与 README 所列 Debug `xcodebuild`：通过。
- `python3 App/Tests/run-settings-regression.py --plugin-tabs -AppleLanguages '(zh-Hans)'` 与 `'(en)'`：均通过。
- `python3 App/Tests/run-settings-regression.py --search-commands`：设置部分“Command tabs, ql label, global cross-tab search, empty results and edit focus passed”通过。完整套件在同一工作区的并发构建环境中多次在 `SettingsRegression.swift:366/384` 的启动器搜索指令循环抖动失败（结果为空），该段落在设置页出现之前、也在本次改动之外；为单独验证设置断言，临时跳过该循环跑通后已恢复测试文件，未保留跳过开关。
- `python3 App/Tests/check-localization.py`：通过，157 个 Swift 源码文件。
- 已查看 `build/command-tabs-search.png`、`command-tabs-built-in.png`、`command-tabs-global-search.png`、`build/plugin-tabs-zh-Hans-ai-light.png`、`plugin-tabs-zh-Hans-ai-dark.png`、`plugin-tabs-zh-Hans-function-light.png`：标签外框与搜索框圆角一致，选中段为 6 pt 圆角，英文长标签（Search Commands／Built-in Commands）完整显示。

## 范围

只调整设置页分类切换的外观与对应回归驱动方式；未改变分类逻辑、搜索行为或其他系统分段控件。
