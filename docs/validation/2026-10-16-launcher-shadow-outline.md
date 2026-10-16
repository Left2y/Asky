# 启动器黑框回归

## 原因与修改

10-14 改用 AppKit `hasShadow` 后，启动器四周重新出现偏下的黑色外框（与 10-11 修过的“黑色外圈与底部双层轮廓”相同）：窗口服务器按 Liquid Glass 的透明包络而非可见外形生成阴影。

启动器与剪贴板主窗口重新关闭 `hasShadow`，外壳与圆形按钮使用新的 `floatingSurfaceShadow`：阴影形状内缩 1 pt，并以“画布矩形 + 外形”的奇偶填充遮罩只保留外形之外的部分。不再使用 `destinationOut` 合成组，避免 10-14 记录的玻璃变深问题。

## 实际检查

- `xcodegen generate` 与 Debug `xcodebuild`（`-skipPackageUpdates`，网络无法拉取依赖）：`BUILD SUCCEEDED`。
- 未做实机截图验证，需在 macOS 26 浅色/深色模式下确认黑框消失、玻璃不变深。
