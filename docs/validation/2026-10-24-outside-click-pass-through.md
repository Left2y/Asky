# 外部点击关闭与背景交互

本次取代 [10 月 11 日](2026-10-11-outside-click-dismissal.md) 的透明承接窗口方案。原方案主动吞掉关闭时的按下、拖动与释放，还会遮住背景滚动。

启动器与剪贴板共用的 `OutsideClickDismissal` 改为本地和全局鼠标按下观察器，不创建窗口。本地观察器始终返回原始事件；全局观察器仅观察。外部左键、右键和其他鼠标键仍触发原有关闭回调，内部点击保留。隐藏时立即移除两个观察器，不再等待鼠标释放。剪贴板固定、拖动与确认状态仍由原控制器决定是否启用观察。

## 实际检查

- `xcodegen generate` 与 README 的 Debug `xcodebuild`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 开发指南的 `OutsideClickDismissalRegression` 编译、运行命令：通过。
  - 同一进程的真实 AppKit 背景按钮在关闭浮窗的同一次点击中执行；内部点击不关闭，后续点击继续有效，右键关闭，移除观察器后不关闭。
  - 独立背景进程接收 WindowServer 投递的滚动、左键按下、拖动、释放及右键按下、释放；滚动保持浮窗，外部按下关闭浮窗，移除全局观察器后浮窗保持。
- `python3 App/Tests/run-launcher-window-regression.py`：未全部通过。浅色通过；深色执行至键盘导航时失败，断言为 `Up must move away from the last result`。本次没有修改键盘导航，也没有把此项记为通过。日志位于 `build/outside-click-launcher-regression.log`。
- 使用上一步编译出的原生回归程序运行 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --accessories`：浅色、深色均通过，覆盖失焦、Escape、重复打开、分类隔离及输入框几何。
- `git diff --check`：通过。

上述鼠标事件为自动化系统事件。没有逐项验证物理鼠标、多显示器、全屏 Space 或第三方应用自己的首次点击激活策略；没有替换已安装的正式版。

README 中英同步说明外部关闭仍保留背景交互。AGENTS.md 未改：没有新模块、边界或开发命令。构建、测试二进制和日志复用现有 `build/` 忽略规则。
