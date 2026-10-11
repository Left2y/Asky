# 启动器黑色外圈与底部双层轮廓修复

## 原因与修改

使用生产 LauncherController 和 LauncherView 在实际桌面复现用户截图中的状态：输入“这是怎么睡”，仅有询问 AI 一行结果，输入框保持焦点。AppKit 窗口阴影包围玻璃的透明外缘，在下方留下偏移轮廓，造成黑色外圈及背景未铺满的观感；输入框已经禁用 focusRing，本次没有修改输入焦点行为。

macOS 26+ 启动器关闭额外窗口阴影，保留原生 Regular 材质自身的光学边缘。搜索外壳使用非交互 Regular；按钮保留自己的交互式玻璃。旧系统兼容分支保留系统窗口阴影。README 中英文和设计系统已同步。

## 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过，181 项 Swift Testing 测试。
- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild`：最终 `BUILD SUCCEEDED`，日志 `build/launcher-surface/build-final.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py`：编译成功，首次运行在 native typing 文本断言失败；该次不记为通过。直接重跑相同已编译的回归应用后，浅色、深色均通过，输入漂移 0 pt；窗口展开收起、键盘导航、滚动投递及背景不跟随滚动通过。日志 `build/launcher-surface/regression-rerun.log`。
- 在 macOS 27.0.1 上实际运行生产控制器与视图的视觉探针，使用隔离临时数据和独立色块/密集文字背景，检查保持输入焦点的单 AI 结果状态。已查看修复前 `build/launcher-surface/before-pinned.png` 与修复后浅色/深色 `after-light.png`、`after-dark.png` 的桌面合成截图；黑色外圈和下方重复轮廓消失，磨砂表面与结果位置保留。
- 视觉探针从源码快照编译，避免同工作区另一任务修改设置源码时产生编译冲突；最终 App 构建和回归均直接使用项目源文件。旧系统阴影分支本次未在旧版 macOS 实机验收。

临时探针、截图和日志均在已忽略的 `build/launcher-surface/`，不打包或安装。

README: updated，双语同步启动器阴影例外。AGENTS.md: unchanged，未改变开发命令、模块边界或持久指导。
