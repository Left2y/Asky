# 搜索框恢复静态放大镜

日期：2026-10-18。

## 行为与实现

- 对照固定/筛选移入输入框前的源码，恢复右侧常驻 MingCute `magnifyingglass`：17 pt 图形、19×24 pt 布局槽、28 pt 右侧留白，语义弱图标色。
- 图标为 Image，显式禁用 hit testing 并从辅助功能树隐藏；没有 Button、点击、悬停、tooltip 或状态切换。空输入、输入文字及命令模式下都常驻，文字区宽度稳定。
- 移除搜索专用固定按钮、按钮交互样式、模型固定状态与回调；搜索窗口失焦或点击外部按原普通窗口规则关闭，确认退出流程的保护仍保留。
- 剪贴板固定功能未修改。原生回归中不再用已删除的搜索固定状态维持测试窗口，沿用测试专用的 onBlur 覆盖。
- README 中英文、PRD、设计系统与 AGENTS.md 同步静态图标、无固定功能和无交互约束。

## 实际执行

- `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：267 项通过，13 个测试目标。
- `python3 App/Tests/check-localization.py`：通过，139 个 Swift 源文件。
- `python3 App/Tests/run-launcher-window-regression.py --accessories`：Aqua / Dark Aqua 均通过；验证 640×52 pt 外壳、输入前后文字区宽度不变、分类搜索隔离、失焦关闭、Esc 和重复打开。
- 已查看首次显示约 80ms 时捕获的 `build/launcher-search-icon-NSAppearanceNameAqua.png` 与 `build/launcher-search-icon-NSAppearanceNameDarkAqua.png`，两种外观右侧均只有静态放大镜。
- `codesign --verify --deep --strict --verbose=1 build/DerivedData/Build/Products/Debug/Asky.app`：通过。
- `git diff --check`：通过。
- 搜索模块源码不再引用 isPinned、onPinChanged、固定按钮和原按钮悬停样式。

## 产物

构建、截图、测试临时数据及日志继续沿用已有 `build/` 忽略规则，不纳入提交。
