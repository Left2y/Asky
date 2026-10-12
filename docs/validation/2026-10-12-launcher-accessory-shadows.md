# 启动器圆形按钮阴影修复

## 原因与修改

搜索框使用 `floatingSurfaceShadow`，固定和筛选按钮只有玻璃背景，因此缺少独立外部阴影。两个按钮现在在 ButtonStyle 外、显隐及缩放动画内使用同一阴影修饰器，形状为 Circle。沿用现有浅色/深色透明度、40 pt 模糊半径、12 pt Y 偏移和 132 pt 窗口透明留白；不改变按钮尺寸与命中区域。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过。
- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令：通过。
- `python3 App/Tests/run-launcher-window-regression.py --accessories`：Aqua / DarkAqua 均通过，覆盖筛选隔离、输入框位置、菜单画布、固定、失焦及 Escape。

## 窗口渲染确认

使用本次 Debug 产物编译真实 LauncherView / LauncherController 预览，临时固定窗口以避免工作过程中失焦关闭。Orca computer-use 捕获了真实 NSPanel。浅色窗口的透明 PNG 在两个按钮下方包含黑色阴影像素，alpha 分别为 15/255、11/255；在白底上检查可见圆形柔和投影，窗口边缘透明，没有裁切。深色稳定窗口在同一采样位置的阴影 alpha 为 43/255、36/255，在灰底上可见完整投影。

窗口单独截图缺少桌面玻璃背景，不能用灰色材质截图判断真实桌面上的玻璃颜色。阴影使用原生窗口捕获的 alpha 层验证；未替换 Applications 中安装的应用。

README: unchanged — 此修复沿用已描述的外部阴影机制，不改变使用方式或开发命令。
AGENTS.md: unchanged — 未改变架构、独立子项目、工作流或持久指引。
