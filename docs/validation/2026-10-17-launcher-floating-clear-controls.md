# 启动器底部悬浮 Clear 玻璃控件

## 修改

- 操作胶囊、更多操作按钮改为主窗口内的底部 overlay，不单独创建子窗口，不作为列表下方的一行参与布局。
- 两处使用系统 `.glassEffect(.clear, in:)`；无额外背景填色或描边，轻阴影为黑色 8%、模糊 4pt、向下 2pt。
- 保留列表底部 68pt 的透明度渐变，上半段保留更多内容可见性，末端渐隐；列表 viewport 继续延伸至控件后方。末项滚动留白确保能滚到控件上方。
- 保留透明度/对比度辅助功能回退、原生更多操作菜单与 `⌘K` 行为。
- 原生回归改查同窗口 overlay 的位置与列表相交关系。合成搜索 provider 仅对 `orca` 返回匹配，避免在计算器检查中注入无关应用操作。

## 验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志 `build/clear-glass-build.log`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，37 tests / 9 suites，日志 `build/clear-glass-core-test.log`。最初未指定 Xcode 的运行失败于 `no such module 'Testing'`，改用上述命令后通过。
- 真实桌面视觉检查：同窗口 overlay 版本浅色截图 `build/clear-glass-overlay-light.png`；通过 computer-use 聚焦输入框后向下滚动，内容实际移动至淘宝/京东/GitHub/Example，按钮仍固定悬浮于底部，末端内容渐隐。截图 `build/clear-glass-overlay-display2.png`。这些是桌面合成后的截图，不能用单窗口离屏截图替代玻璃背景的判断。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --actions-preview`：Aqua / Dark Aqua 均通过，日志 `build/clear-glass-actions.log`；验证 overlay 坐标、列表位于控件后方、`⌘K` 原生菜单、复制路径/链接、选中项操作更新、计算器操作。暗色桌面截图 `build/clear-glass-overlay-dark.png`。
- 同一新编译二进制以 `--actions` 无预览等待运行：Aqua / Dark Aqua 均通过，日志 `build/clear-glass-actions-focused.log`。
- `git diff --check`：通过。README 中英文及设计系统已同步；AGENTS.md 更新底部 overlay 的约束，其他独立窗口表面保持原有规则。构建、日志和截图复用已有 `build/` 忽略规则。
