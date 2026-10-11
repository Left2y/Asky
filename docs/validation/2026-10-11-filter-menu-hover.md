# 筛选菜单悬停背景

- 为筛选菜单添加逐行鼠标悬停状态，使用现有 `kInteractionHover` 背景与 12 pt 圆角。
- 移出该行或关闭菜单时清除悬停；保留选中项背景及勾选。布局与点击选择逻辑不变。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过（19 个 Swift Testing 测试，另见 XCTest 输出）。
- `xcodegen generate`：通过。
- README 中 Debug `xcodebuild` 命令：通过。
- `python3 App/Tests/run-launcher-window-regression.py --accessories`：未完成，共享 DerivedData 中 Scheduler.o 在编译期间被另一构建修改。
- 已重新启动 Debug 应用并查看实际启动器窗口。菜单操作被应用文件持续替换中断，因此真实指针悬停视觉检查未完成。
- README 与 AGENTS.md 无需修改：本次仅修复现有菜单的背景反馈，无命令或架构变更。
- 未提交：筛选菜单本身位于任务开始时已有的未提交 LauncherView / LauncherModel 改动中，本修复依赖这些改动，不能形成完整独立提交。
