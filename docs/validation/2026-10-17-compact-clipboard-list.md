# 剪贴板历史列表紧凑单行布局

左侧历史列表移除复制时间副标题，沿用当前搜索结果的 `LauncherLayout.rowHeight`（38 pt）与 `rowIconSize`（24 pt）。保留右侧详情的复制时间、固定标识及复制和拖放交互。

实际验证：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。首次未设置 DEVELOPER_DIR 时缺少 Testing 模块；使用 Xcode 工具链后通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过布局切换、持久化、选择、筛选、固定及复制回归。
- 查看新生成的 `build/clipboard-layout-list-image.png`：左侧无时间副标题，文字和 24 pt 图标在紧凑行内居中，右侧详情仍显示复制时间。

构建与回归使用当前工作区，包含已有的搜索结果紧凑化改动；没有替换已安装的 Asky。
