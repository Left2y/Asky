# Debug 重新构建

- 基于 `2fc5364`，包含搜索提示 14 pt 字号与 16 pt 底部留白。
- `xcodegen generate`：退出码 0。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：退出码 0，`BUILD SUCCEEDED`。
- 产物：`build/DerivedData/Build/Products/Debug/Asky.app`；构建日志：`/tmp/asky-debug-rebuild.log`。本次未启动应用。
- README: unchanged；AGENTS.md: unchanged：仅重新构建和记录结果，开发流程未变。
