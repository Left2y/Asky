# 图片剪贴板时间戳名称

图片记录在剪贴板列表与主搜索结果中使用复制时间作为名称，格式为 `yyyy_MM_dd_HH_mm_ss`，按本地时区、固定公历生成；卡片辅助功能名称同步。既有图片记录直接使用已保存的复制时间，无需迁移。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过，覆盖布局、持久化、默认值、选择、筛选和复制。
- 检查[新构建实际窗口截图](../../build/clipboard-layout-list-image.png)：图片行显示 `2026_10_21_20_01_50`，名称完整、图片预览正常。主搜索结果的名称共用同一属性，未单独进行主搜索窗口视觉验收。

README 中英文同步名称格式。AGENTS.md 规则及模块边界未改变。构建与截图沿用现有 `build/` 忽略规则。
