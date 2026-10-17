# 启动器底部操作按钮悬停反馈

- 主操作与「更多」共用胶囊 ButtonStyle，玻璃保留在按钮内部，叠加现有 `interactionHover` 语义色；悬停强度 0.6，按下强度 1，禁用时隐藏反馈层。
- 悬停 120ms、按下 100ms ease-out；系统「减少动态效果」开启时立即切换。反馈层不拦截点击，也不参与辅助功能树。

## 实际运行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志 `build/launcher-hover-build.log`。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，日志 `build/launcher-hover-core-tests.log`。
- 通过临时的 LauncherWindowRegression 检查程序运行真实 SwiftUI / AppKit 窗口，固定窗口后依次移动鼠标到主操作、更多及按钮外，捕获浅色/深色桌面截图。实际桌面中玻璃外形保持，按钮悬停高亮、移出恢复。深色截图：`build/launcher-hover-DarkAqua-primary-hover.png`、`build/launcher-hover-DarkAqua-more-hover.png`、`build/launcher-hover-DarkAqua-hover-exit.png`；浅色截图使用同名 Aqua 文件。

## 验证范围与限制

原有完整 `--action-bar` 回归尝试因窗口失焦清空搜索，以及后续 Cmd K 状态断言未通过，不能记为菜单回归通过。并发编辑又加入复制文件代码，与原构建核心库暂时不匹配；最终悬停检查使用 `build/launcher-hover-sources/` 隔离源码快照（本次样式、原 LauncherModel、不含并发 copyFile 变更），独立检查程序位于 `build/launcher-hover-inspection/`。临时检查只验证窗口可见与鼠标状态截图，不执行完整菜单断言；不把该程序最终成功提示当作完整回归通过。

按下、禁用与减少动态效果分支经过源码检查，未做独立自动化交互验收。未替换已安装的 Asky。日志、截图、快照和检查程序均由现有 `build/` 忽略规则覆盖。

README 与 AGENTS.md 无需因这次局部交互修复更新；用法、命令与架构边界不变。保留原有去掉「更多」图标和并发复制文件等修改，不纳入本次提交。
