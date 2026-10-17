# 剪贴板类型筛选

2026-10-17。

## 行为

- 搜索框右侧、固定按钮左侧新增筛选按钮，默认“全部”；下拉菜单依次为全部、图片、视频、文本、文件。
- 沿用启动器筛选的 220pt 宽、24pt 圆角独立玻璃窗口，以及菜单选中勾与悬停状态。菜单右边缘与筛选按钮右边缘对齐，按钮下方间距为 6pt。
- 搜索与剪贴板统一使用 MingCute `filter_2_line`（固定上游版本中的 `filter_2`），替换旧漏斗图标；新增视频图标。
- 类型筛选与搜索取交集；分类前扩大查询范围，避免最近 100 条中的其他类型遮蔽较早记录。每次重新打开剪贴板恢复全部。
- 视频按存储路径的扩展名分类，整组均为视频时归入视频，其余文件组归入文件；原文件失效不改变分类。

## 已执行检查

- `xcodegen generate` 与 README 中的 Debug `xcodebuild`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --filters`：通过。覆盖五种类型、超过 100 条较新记录时的较早匹配、搜索交集、列表与卡片共用筛选、重新打开恢复全部、菜单窗口生命周期和按钮/菜单定位。
- 中英 `Clipboard.strings` 的 `plutil -lint`：通过。
- 原生回归窗口截图已检查；实际窗口点击筛选按钮和菜单后，辅助功能回读显示“视频”及单条 `sample movie.mp4`，菜单收起。

回归截图与日志位于已忽略的 `build/`，包括 `clipboard-filter-menu.png`、`clipboard-filter-header.png`、`clipboard-filter-list-video.png`、`clipboard-filter-regression.log` 和 `clipboard-filter-build.log`。未把构建目录加入版本控制。

AGENTS.md 检查：现有 App 与核心包规则覆盖本次改动，没有新增架构边界或开发流程，保持不变。README 已同步中英文功能与筛选回归命令。
