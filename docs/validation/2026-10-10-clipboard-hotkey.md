# 剪贴板快捷键注册修复

- 新组合键：Ctrl + Option + Command + Shift + F9（⌃⌥⌘⇧F9）。菜单栏和设置文案同步更新。
- 原实现为每个快捷键安装相同 Carbon 事件处理器，第二次安装会失败，且剪贴板把所有失败都显示为占用。现在共用一个处理器，以事件 ID 分发；最后一个快捷键注销时移除处理器。真正占用与其他错误分别显示。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 核心包 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：138 项测试通过。首次不指定 Xcode 的运行因 Command Line Tools 缺少 Testing 模块失败，切换 Xcode 后通过。
- `python3 App/Tests/run-settings-regression.py`：原生浅深色快照检查通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/HotKey.swift App/Tests/HotKeyRegression.swift -o build/hotkey-regression`，随后 `build/hotkey-regression`：多快捷键同时注册、注销其中一个后替换、全部注销后重新安装处理器均通过。
- 退出旧 Debug 进程，打开新 Debug 构建。System Events 投递新组合键后，Orca 窗口清单观察到“剪贴板历史”（pid 61483，window 56663），确认实际唤起。没有读取历史内容。

README 中英文已同步。AGENTS.md 无需修改：模块边界与开发流程未改变。未打包 Release 或安装应用。
