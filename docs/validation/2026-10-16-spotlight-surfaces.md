# Spotlight 式浮动表面

## 原因与修改

透明留白画布加系统阴影会描出偏下黑框，自绘阴影又曾让浅色玻璃变深，两种做法反复回归。现改为 Spotlight 式结构：

- 每个玻璃表面独立一个窗口，窗口帧等于玻璃外形，`hasShadow = true`。macOS 26 由 AppKit `NSGlassEffectView` 填满窗口（`App/Sources/SurfaceWindow.swift`）。
- 启动器外壳、固定与筛选两个圆形按钮、筛选菜单、提示条分别是独立窗口，附属表面挂为外壳的子窗口。按钮分离动画由 `SurfaceSpring` 在显示链路上驱动窗口帧。
- 剪贴板主窗口为 900 × 244 精确尺寸，完整预览同样装入玻璃窗口，状态提示改为子窗口。
- 删除 `shadowPadding`、`floatingSurfaceShadow` 及相关常量。

首版在结果展开后的窗口角落仍出现方角黑边。按窗口单独截图（`screencapture -o -l`）可见，玻璃在圆角外留有 alpha 4–10 的微弱像素，窗口服务器据此生成矩形阴影。现将 `NSGlassEffectView` 与内容层都按同一圆角（continuous）裁剪，角落 alpha 归零。

## 实际检查

- `xcodegen generate` 与 Debug `xcodebuild`（`-skipPackageUpdates`）：`BUILD SUCCEEDED`，改动文件无警告。
- `build/shadow-probe` 实机截图，浅色与深色，空状态、输入、结果、清空各 3 轮：圆角处无方角黑边，阴影沿外形，玻璃未变深；窗口截图四角 alpha 为 0。
- `run-clipboard-regression.py`：通过。
- `run-launcher-window-regression.py` 的 `--accessories`（连续 3 次）、`--ai-routing`、`--bookmarks`、`--command-icons`、`--alias-routing`、`--system-app-names`：通过。
- 默认模式（`checkWindow`）在本机间歇失败于 “system wheel must reach launcher”、“initial search must finish” 等时序或焦点断言。以 HEAD 源码运行同一测试也出现相同的间歇失败，判定为既有不稳定，非本次改动引入。
