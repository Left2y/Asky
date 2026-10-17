# 剪贴板列表预览来源图标

列表式右侧预览底部在来源 App 名称前显示 28×28 pt 真实应用图标，复用卡片式的 `ClipboardAccess.sourceIcon`；无法解析来源时沿用卡片式的剪贴板图标。

## 实际验证

- `xcodegen generate` 与 README 的 Debug `xcodebuild`：通过。
- `Packages/KulaCore` 中使用 Xcode 工具链执行 `swift test`：258 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过；布局切换、选中项保留、搜索、固定与复制正常。
- 查看最新真实窗口截图 `build/clipboard-layout-list-image.png` 与 `build/clipboard-layout-list-text.png`，检查来源图标及未知来源回退的布局。

README 与 AGENTS.md 保持不变：此修复未改变使用方式、开发命令或架构约定。截图和回归产物沿用现有 `build/` 忽略规则。
