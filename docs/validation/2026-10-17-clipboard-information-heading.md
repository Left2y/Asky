# 剪贴板详情标题移除

- 修改：移除剪贴板详情信息区顶部的“信息”标题，保留来源、类型、尺寸、大小与复制时间。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过（BUILD SUCCEEDED）。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `git diff --check`：通过。
- 未进行实际窗口视觉验收。
- README 与 AGENTS.md 无需调整：本次仅移除局部标题，未改变使用方式、开发命令或架构约束。
