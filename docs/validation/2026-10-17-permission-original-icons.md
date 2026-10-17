# 系统权限列表恢复原图标

仅将 `PermissionSettings.swift` 中权限行和 Chrome 书签行恢复为 MingCute 统一替换前的 SF Symbols，保留原有字号、字重、彩色底、尺寸、布局与权限行为。该文件与 `6154ffb^` 中版本一致；其他入口继续沿用现有图标。

实际验证：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 本次修改的差异与空白检查通过；未运行新构建的原生窗口视觉检查，未重新申请系统权限。

README 与 AGENTS.md 无需修改：本次仅恢复局部图标，没有新增使用方法、命令或架构边界。生成工程与构建缓存沿用现有 `.gitignore`，未纳入提交。保留工作区中其他并行修改。
