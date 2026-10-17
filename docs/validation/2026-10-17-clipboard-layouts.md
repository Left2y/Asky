# 剪贴板卡片／列表布局

日期：2026-10-17。

## 实现

- 初始布局为卡片式；顶部玻璃圆形按钮在卡片式与列表式之间切换。选择在当前应用进程内保留，重启应用恢复卡片默认值。
- 列表式为左侧历史列表、右侧选中内容预览，显示来源、记录时间与大小；图片等比显示，长文本独立纵向滚动。
- 切换保留搜索与选中项；列表点击选中，上下键移动，回车沿用粘贴流程；右键菜单提供复制、固定与删除，拖放共用现有原生拖放实现。
- 卡片窗口高度 244 pt，列表窗口高度 560 pt，并限制在可用屏幕内；沿用单窗口玻璃裁剪与系统阴影。

## 实际检查

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：258 项测试通过。直接使用 Command Line Tools 的首次运行缺少 `Testing` 模块；切换到 Xcode 工具链后通过。
- 布局回归使用真实 `ClipboardController`、临时数据库及原生窗口，检查默认卡片、列表尺寸、切换后选中项保留、搜索、固定与复制。
- 已查看实际窗口截图：`build/clipboard-layout-list-image.png`、`build/clipboard-layout-cards.png`；列表显示选中图片与来源信息，卡片布局保持原有排布。
- 使用 computer-use 点击实际窗口顶部切换按钮，再读回窗口由 900 × 560 pt 变为 900 × 244 pt，确认交互生效。

截图及测试应用保存在已忽略的 `build/` 下。此任务没有重新验收跨应用粘贴、外部拖放目标、旧版 macOS 或多显示器场景。
