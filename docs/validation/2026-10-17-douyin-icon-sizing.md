# 抖音图标内部比例

> 本记录中的 1.12 倍内部缩放已撤回。当前实现与验证以 `2026-10-17-command-icon-contours.md` 为准，不能将本记录视为视觉验收通过。

抖音的 512 × 512 px 资源含深色底板，音符的可见范围约为 `(82, 60, 430, 452)`；原先按 20 pt 绘制时音符只有约 15.3 pt 高。

在 `CommandIcon` 中对抖音增加 1.12 倍内部缩放，仍在原 20 pt 圆角底板内裁剪；音符约为 17.2 pt 高，共享 24 pt 图标槽及其他品牌保持现有尺寸。设置、启动器范围图标和结果共同使用该组件。

实际运行：

- `xcodegen generate`：通过。
- README 中的完整 Xcode Debug 构建命令：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：262 个 Swift Testing 测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --command-icons`：首次在窗口截图读取处遇到 `CommandIconsRegression Code=3`；重新执行刚编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --command-icons` 后深浅色均通过。
- 已查看新生成的 `build/command-icon-NSAppearanceNameAqua-dy.png` 与 `build/command-icon-NSAppearanceNameDarkAqua-dy.png`：音符完整，深色底板保持原尺寸，范围图标与结果图标一致。

构建和截图沿用现有 `build/` 忽略规则；未替换已安装应用。
