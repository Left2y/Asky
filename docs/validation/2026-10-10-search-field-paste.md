# 搜索框粘贴修复验证（2026-10-10）

## 问题

KulaHere 以 accessory 模式运行，没有默认主菜单。⌘V/⌘C/⌘X/⌘A/⌘Z 等快捷键要靠菜单项转发给 field editor，所以启动器搜索框、对话搜索框等 `NSTextField` 都无法粘贴。

## 修复

`App/Sources/EditMenu.swift` 在启动时安装一个隐藏的主菜单，包含"撤销、重做、剪切、拷贝、粘贴、全选"。accessory 应用不显示菜单栏，但 key window（包括 non-activating panel）收到的快捷键仍会经由主菜单发送给第一响应者。

## 检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Sources/EditMenu.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression && build/launcher-input-regression`：通过。新增检查：主菜单中存在 ⌘V 菜单项；该菜单项的 action 送达活动 field editor 后，剪贴板文本被插入搜索框。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild`：`BUILD SUCCEEDED`。
- `python3 App/Tests/run-launcher-window-regression.py`：编译失败，原因是 `LauncherView.swift` 找不到 `SettingsShortcut`。该失败在本次修改前已经存在（stash 后同样失败），与本修复无关。
- 尚未在真实应用中手动按 ⌘V 验证。
