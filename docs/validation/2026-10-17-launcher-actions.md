# 启动器悬浮操作区验证

日期：2026-10-17。工作区：`/Users/niallyoung/orca/Asky`。基线：`dbf837d`；开始时工作区干净。

## 实现与实际窗口

- 结果底部左侧显示当前选项的主要操作，右侧仅在有附加动作时显示「更多 ⌘K」。图标复用已打包的 MingCute 资源。
- 操作胶囊使用现有 Regular 玻璃；结果列表使用底边 alpha 渐隐与末尾滚动留白。更多菜单是独立、非 key、开启系统阴影的玻璃子窗口，不改变启动器尺寸。
- 应用、文件提供访达显示与路径复制，沿用用户配置的快捷键；链接和 Chrome 标签页提供复制链接；AI、计算结果没有空的更多菜单，汇率保持只读。
- 菜单在输入变化、选择变化、目标被异步批次替换或面板隐藏时关闭。

已查看本次真实窗口截图：浅色/深色的操作区与菜单、末尾文件选中项、AI 主要操作、计算复制操作。截图位于被既有规则忽略的 `build/launcher-actions-*.png`。例如：

- [浅色菜单](../../build/launcher-actions-NSAppearanceNameAqua-menu.png)
- [深色菜单](../../build/launcher-actions-NSAppearanceNameDarkAqua-open.png)
- [深色末尾文件](../../build/launcher-actions-NSAppearanceNameDarkAqua-last-row.png)
- [计算结果](../../build/launcher-actions-NSAppearanceNameAqua-calculation.png)

参考了 [Tinycast RootPaletteView](https://github.com/abue-ammar/tinycast/blob/main/Tinycast/Palette/RootPaletteView.swift) 中浮动控件、边缘渐隐与键盘路由的组织方式；本次界面、动作描述和状态实现使用 Asky 现有组件及样式。

## 已执行检查

| 检查 | 结果 |
| --- | --- |
| `xcodegen generate` | 通过 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build` | 通过 |
| 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | 通过，13 个测试可执行程序共 261 个 Swift Testing 测试 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --action-bar` | 浅色、深色通过 |
| `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --compact-results` | 浅色、深色通过 |
| `git diff --check`、本次新增本地化键去重检查 | 通过 |

`--action-bar` 在真实 NSPanel 上发送原生键盘事件，检查 ⌘K 打开/关闭、按住不重复切换、上下键仅移动菜单高亮、原搜索编辑器与查询保留、关闭后恢复结果导航、回车执行复制路径、Escape 仅关闭菜单、查询变化关闭旧动作、AI 无空菜单、计算提供复制、清空后恢复 52 pt 输入框。路径复制验证使用临时文件；未通过这项检查宣称实际打开了文件、切换了真实 Chrome 标签页或完成访达显示。未替换 `/Applications` 中安装的应用。

## 扩展回归

默认窗口回归已额外执行，滚轮投递、搜索框焦点与键盘边界检查通过，但在 `slow pending search must retain the result footprint` 断言失败。因此不将完整窗口回归记为通过。使用 `git show dbf837d:...` 提取全部 App 源码及原窗口回归到项目外临时目录，复用相同 Debug 依赖编译基线。为独立核对布局，仅在临时测试副本中跳过系统滚轮投递和滚轮行为阶段；搜索输入、等待与窗口高度断言均保持原样。基线同样在 `slow pending search must retain the result footprint` 断言失败，输入漂移均为 0 pt。该既有失败没有在本次功能中改写或弱化断言。

## 文档与产物

`README: updated`：中英文同步说明悬浮操作区、菜单快捷键、按选项可用性与回归命令。

`AGENTS.md: unchanged`：既有 App / KulaCore 边界、玻璃窗口规范和开发入口仍适用，本次没有新增独立子项目或持久开发规则。

截图、回归可执行程序、Xcode 工程与 Swift 构建产物复用现有 `build/`、`Asky.xcodeproj/`、`Packages/KulaCore/.build/` 忽略规则，没有新增忽略规则。
