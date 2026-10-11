# 外部点击关闭浮窗

## 修改

启动器与剪贴板未固定时，在浮窗下方为每个屏幕放置不激活应用的透明 NSPanel。外部鼠标按下关闭浮窗，承接窗口保留到对应鼠标释放，消费按下、拖动与释放，避免下方控件执行。内部点击与剪贴板预览保留；固定时移除承接窗口，取消固定时恢复。失焦或 Escape 关闭时清理监听器和窗口。

不再使用剪贴板的全局鼠标监听器：该 API 只能观察已发送给其他应用的点击，无法消费它。使用 AppKit 窗口承接，不增加辅助功能权限或全局 event tap。

## 实际检查

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，Swift Testing 19 项。
- README 新增的 `OutsideClickDismissalRegression` 编译、运行命令：通过。真实显示 AppKit 窗口、背景按钮与浮窗，通过 WindowServer 鼠标输入验证内部点击、外部关闭、拖动/释放、右键关闭、第二次点击恢复背景按钮，以及移除承接窗口后的固定模式。先验证背景按钮可以接收输入，再验证关闭点击不执行该按钮。
- `python3 App/Tests/run-launcher-window-regression.py --accessories`：浅色、深色均通过，覆盖真实启动器固定、失焦、Escape、筛选和布局。
- `git diff --check`：通过。

独立窗口回归中的背景按钮属于同一测试进程；跨应用按钮、多显示器、全屏 Space 和物理鼠标未逐项验收。Debug 应用已重新启动；通过 UI 工具获取了新构建启动器的输入、固定和筛选控件。随后截图获取返回 `noWindowsAvailable`，未把该操作记作完整手工点击验收。

## 文档与 Git

README 中英同步新增独立原生回归命令。AGENTS.md 无需变化：没有新模块边界或开发规范。

构建和回归产物由现有 `build/` 忽略规则覆盖。工作区开始时已有未提交的启动器、剪贴板视觉与筛选/固定代码；本次启动器修改依赖其中未提交的 `isPinned` 状态，无法在不混入既有改动的情况下形成完整可独立构建的提交，因此保留全部修改，未创建混合提交。
