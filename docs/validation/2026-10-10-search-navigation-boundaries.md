# 搜索结果键盘导航边界

搜索结果的 ↑/↓ 选择改为限制在首项与末项之间。连续向下到达末项或向上到达首项时保持当前选择，不再循环到另一端；反向按键仍正常移动。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：140 项测试、28 个测试套件通过。首次使用 Command Line Tools 执行时缺少 `Testing` 模块，切换到 Xcode 后通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
- `python3 App/Tests/run-launcher-window-regression.py`：浅色与深色原生窗口均通过。使用临时数据库与模拟搜索源，在真实搜索编辑器的方向键命令路径中连续移动超过结果数量，确认停在两端；边界处继续按键不会使列表跳到另一端，反向按键可以离开边界，输入焦点保持。现有屏外选中项滚入视野、鼠标/触控板滚动和背景窗口不跟随滚动检查也通过。

构建日志与回归日志位于已忽略的 `build/search-navigation-*.log`。这次提交不包含原先未提交的 `LauncherView.swift` 玻璃边缘调整；本地构建和原生窗口检查使用当前工作区视图。

README 中英文已同步边界行为。现有构建命令和模块边界未改变，AGENTS.md 无需修改。
