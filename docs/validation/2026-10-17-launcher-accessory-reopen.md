# 启动器重复显示与按钮消失

## 已确认的触发路径

`LauncherController.show()` 原先无论窗口是否可见都会调用 `reveal.set(0)`，将固定与筛选按钮窗口的透明度归零。窗口已显示时，`LauncherChrome.accessories` 仍然为 true，没有状态变化来重新启动显示动画。因此菜单栏 / Dock 再次打开已经显示的启动器会留下透明按钮；关闭重开会重建界面并恢复。

这是一条已复现的按钮消失路径，尚不能认定它完整解释用户所述的“只有固定按钮丢失”。

## 修正

- 已显示的启动器再次收到 show 时只恢复 key 状态，保留布局、搜索会话和按钮显示进度。
- 新建界面时，在安装 SwiftUI 树之前初始化显示进度，避免初次布局发布 chrome 后又被清零。
- 两个按钮仍共享相同的 64 × 64 几何、圆角与原生玻璃 / 系统阴影；没有新增描边或调整玻璃材质。系统独立玻璃表面的背景采样可能导致边缘亮度差别，此次没有逐像素证实截图差异的来源。

## 实际验证

- 修复前：新增“已显示窗口再次 show”断言，执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --accessories`，在 `showing a visible launcher must preserve both accessory windows` 处失败。日志：`build/launcher-accessory-before.log`。
- 修复后：同一命令通过浅色 / 深色，覆盖已显示后再次 show、动画开始后 30 / 120ms 再次 show、每种外观六轮关闭重开，以及原有筛选、输入位置、菜单、固定 / 失焦 / Escape 行为。检查两个按钮均可见、alpha > 0.99、内容视图存在，尺寸和系统阴影配置一致。日志：`build/launcher-accessory-after.log`。
- `xcodegen generate` 与 README 中 Debug `xcodebuild` 命令通过。日志：`build/launcher-accessory-generate.log`、`build/launcher-accessory-build.log`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 已运行，未全量通过：`AgentHostTests.RealRuntimeIntegrationTests.unreachableModelFailsAndProcessIsGone` 未进入 running 状态、没有 runningPID，两处断言失败。此次未修改 AgentRuntime / AgentHost，也未确认该失败的根因。日志：`build/launcher-accessory-swift-test.log`。
- 启动新编译的 `LauncherWindowRegression --accessories-preview` 后尝试 Orca 实际截图；能通过 PID 定位进程，但未枚举到可访问窗口，`get-app-state` 返回 `window_not_found`。因此不记实际玻璃截图验收通过，预览进程已停止。

未替换已安装的 Asky，未打包或发布。README 与 AGENTS.md 无需修改：既有行为修复，没有新增命令、改变系统接口边界或开发流程。构建和验证产物沿用已有 `build/` 忽略规则。
