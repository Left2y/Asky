# 完全清空普通搜索时收起

按用户截图反馈调整固定高度规则：结果数量变化仍保持 433 pt 展开高度；普通搜索完全清空（含仅空白字符）后收回 52 pt 单行。空查询的 sw 等搜索模式保持展开，退出模式回到空的普通搜索时收起。活动终端输出不视为完全清空。阻止清空后残留状态重新触发展开。

实际执行：

- `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令通过，日志 `build/empty-collapse-build.log`。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：43 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --fixed-expanded`：浅色、深色通过，包括单条/多条结果固定高度、空 sw 不收起、退出空 sw 收起、仅空白输入收起、编辑器身份和重新打开。
- 使用同次编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression` 运行 `--result-motion`、`--command-transition`、`--compact-results`、`--action-bar`：最终浅色、深色通过。覆盖清空收缩、收缩途中再次输入、输入框和窗口顶边稳定、模式切换、圆角及操作区。`--result-motion` 首次在初始展开的中间帧数量断言失败，未改代码直接重跑通过；不将这些程序采样当作所有帧均按刷新率提交的证明。

已查看实际深色收起截图 `build/launcher-compact-empty-NSAppearanceNameDarkAqua.png`，确认空查询恢复单行且不再显示分隔线和空结果区。README 中英文、PRD 与设计系统已同步。日志、截图及基线副本沿用 `build/` 忽略规则；未进行物理键盘验收。
