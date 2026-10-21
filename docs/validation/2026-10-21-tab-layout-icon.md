# 标签页入口 layout_4_line 图标验证

- 将共享 `LauncherFunctionIcon.Kind.tabs` 图形从 `web` 替换为 MingCute `layout_4_line`，使用项目锁定版本的 regular `layout_4` SVG；紫色底板、白色图形、尺寸与圆角保持不变。
- 同步资源清单、Swift 映射与设计系统中的图形名称。当前工作区已有的窗口搜索也复用 `.tabs`，因此沿用此共享图形。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：退出码 0，全部测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --search-commands`：通过。
- 已查看新构建资源在原生回归窗口中的 `build/tab-entry-light.png`、`build/tab-entry-dark.png`，两种外观均显示白色 layout_4 图形与紫色底板。
- 未验证真实 Chrome 标签切换；本次仅修改图形资源与映射。
- README: unchanged；未改变使用方式、命令或依赖。
- AGENTS.md: unchanged；沿用已有图标规范与构建流程。
