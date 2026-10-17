# 剪贴板列表图标与文档预览

- 文档类列表详情居中显示 256pt 系统文件图标，文件名置于图标下方，间距 16pt；视频继续使用原生播放器。
- 左侧保留与搜索结果相同的 32pt 图标栏，图形缩为 24pt。纯文本使用 16pt clipboard 图标、24pt neutral 背景及 6pt 圆角，不再显示来源应用图标。
- README 已同步中英文说明；AGENTS.md 无需变动，既有 App 与 ToolService 边界、构建入口均保持适用。

## 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）退出码 0，260 项通过。
- `xcodegen generate` 及 README 的 Debug `xcodebuild` 命令通过；添加下方文件名后再次构建通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts` 通过，验证布局、持久化、选择、搜索、固定和复制。
- 检查 `build/clipboard-layout-list-text.png`，确认纯文本 clipboard 图标、中性圆角背景和缩小的图片图标。
- 重启实际 Debug 应用，新进程 PID 24191；通过 Orca 打开剪贴板并检查窗口，文档显示图标及下方 `文件分类验证.md`。截图由 `/tmp/asky-document-name-ui2.json` 指向的本机临时文件保存。
- 回归截图及测试产物由已有 `build/` 忽略规则覆盖，不纳入 Git。保留工作区原有命令设置及本地化改动。
