# 用户提供的启动器功能图标

使用用户提供的 `Bookmark.png`、`Link.png`、`Power.png`，分别为橙底书签、蓝底链接、红底电源。三张原图均为 99×99 PNG，逐字节复制进 Asset Catalog，移除被替换的 SVG，不修改原始图片。资源保留原名称，PNG 标记为 original 渲染。

`LauncherFunctionIcon` 统一在 24 pt 图标槽内展示 20 pt 图形，裁切 4.5 pt 连续圆角。结果中的书签、链接、关闭和输入框的书签入口共用此视图，不额外叠加背景、阴影或高光。

## 实际验证

- 三个项目 PNG 与用户 Downloads 中的原图逐字节一致。
- `xcodegen generate` 和 README 的 Debug `xcodebuild`：通过。
- `Packages/KulaCore` 中使用 Xcode 工具链运行 `swift test`：262 项通过。
- 原生资源预览检查 24/48 pt 深浅背景与圆角：`build/supplied-rounded-icons-preview.png`。
- 临时启动器回归副本重新编译，检查排序、范围、深浅色实际窗口截图：通过。截图位于 `build/quit-asky-results-NSAppearanceNameAqua.png` 和 `build/quit-asky-results-NSAppearanceNameDarkAqua.png`。
- 未重测完整退出确认流程，原有 `QuitSheetMissing` 限制仍见前次验证记录。

README 中英文与设计系统已同步。AGENTS.md 无新增命令或边界变化。临时程序与截图沿用 `build/` 忽略规则；没有替换已安装的 Asky。
