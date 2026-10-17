# 启动器书签、链接与关闭图标

按用户选择，将三个功能图标统一为扁平色块：24 pt SVG 画布，20 pt 圆角底板，4.5 pt 圆角，蓝灰底色 `#DDE7F1` 与蓝色 `#436589`，1.7 pt 符号线宽。关闭使用电源符号，不使用 Asky 应用 Logo。删除不再使用的书签与链接玻璃 PNG，原有资源名称和调用位置不变。

## 实际检查

- `xcodegen generate` 和 README 的 Debug `xcodebuild`：通过。
- `Packages/KulaCore` 中使用 Xcode 工具链执行 `swift test`：262 项通过。
- 通过临时 AppKit 预览程序加载新构建的 `Assets.car`，检查三个图标的 24/48 pt 深浅背景效果：`build/flat-launcher-icons-preview.png`。
- 复用现有退出回归的临时副本，仅运行排序、查询范围及深浅色实际窗口截图：通过。查看 `build/quit-asky-results-NSAppearanceNameAqua.png` 和 `build/quit-asky-results-NSAppearanceNameDarkAqua.png`，关闭入口已显示电源图标。
- 初次完整退出回归在确认步骤报 `QuitSheetMissing`，不能记为退出确认流程通过；此次只调整资源，未修改确认逻辑。

README 中英文与设计系统同步。AGENTS.md 无变动：没有新增命令、架构边界或独立模块。临时程序与截图复用 `build/` 忽略规则。未替换 `/Applications/Asky.app`。
