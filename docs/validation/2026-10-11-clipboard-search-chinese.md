# 剪贴板搜索占位文字中文化

将剪贴板搜索框的 `Search your clipboard contents` 改为 `搜索剪贴板内容`。

实际验证：

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore` 中）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 运行现有 `run-clipboard-regression.py --preview`，使用新编译的 ClipboardController 打开原生窗口；截图和辅助功能树均确认占位文字为“搜索剪贴板内容”。预览首次因默认 SDK 26.5 与构建 SDK 27.0 不一致失败；显式设置 `DEVELOPER_DIR` 与 `SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk` 后成功。

仅验证占位文字；没有运行完整剪贴板回归，没有打包或安装 Release。

README 与 AGENTS.md 无需变更：该文案修复未改变使用流程、开发命令或架构边界。
