# 剪贴板头部间距

- 将搜索框和右侧固定按钮之间的 `HStack` 间距从 40 改为 16 pt；按钮尺寸和头部内边距不变。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- 用 `App/Tests/run-clipboard-regression.py --preview` 启动当前源码的实际剪贴板窗口，使用 computer-use 截图检查：搜索框与固定按钮间距收紧，显示正常。该模式仅用于视觉检查，不代表完整剪贴板回归通过。
- 首次启动回归工具时环境默认 SDK 为 26.5，与构建模块所用的 27.0 不一致；显式设置 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 和 `SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk` 后成功编译并启动。
- README: unchanged：仅调整局部间距，使用方式和开发命令不变。
- AGENTS.md: unchanged：没有新增架构边界或持久开发规则。
