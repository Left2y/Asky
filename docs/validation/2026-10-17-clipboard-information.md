# 剪贴板列表信息区

日期：2026-10-17。

- 右侧预览下方新增“信息”标题，来源、类型、尺寸、大小、复制时间按两列逐行对齐；来源保留真实应用图标。中英文标签均已补齐。
- 图片类型与像素尺寸读取原图元数据，不使用缩略图或 Retina point 尺寸。文件大小读取原文件字节数，不显示序列化路径的大小；文件缺失、目录或不适用的尺寸显示“—”。视频目前不读取像素尺寸。
- 文件预览图标缩小至 160 pt，为信息行保留空间；沿用现有玻璃窗口与阴影。

实际验证：

- `xcodegen generate` 通过。
- README 的 Debug `xcodebuild` 命令通过。
- `Packages/KulaCore` 中使用 Xcode 工具链运行 `swift test` 通过；新增测试后运行 `swift test --filter ClipboardAccessTests`，9 项通过，覆盖原图像素、真实文件大小、文件删除后的回退。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts` 通过，覆盖布局切换、选择保留、筛选、固定、复制及持久化。
- 已查看实际窗口截图 `build/clipboard-layout-list-image.png` 和 `build/clipboard-layout-list-text.png`：图片像素信息完整、五行对齐，长文本预览与信息区互不遮挡。
- `git diff --check` 通过。回归编译仍有既有 AppUpdater、PermissionSettings 与 SettingsStyle 警告。

截图和测试产物沿用 `.gitignore` 的 `build/` 忽略规则。本次未重新验收跨应用拖放和旧版 macOS。
