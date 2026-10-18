# 浅色模式非 key 玻璃提亮

## 原因

启动器外壳是 key 窗口，固定与筛选两个圆形按钮是永远无法成为 key 的子窗口。系统会把非 key 窗口的 Liquid Glass 渲染成更暗的 inactive 材质。10-17 的补偿只在深色下成立：浅色用 1.5% 白色透明叠层，几乎不提亮。

实机按窗口帧取中心像素（白底、浅色外观）：

| 表面 | 像素 |
| --- | --- |
| key 外壳 | 253 |
| 非 key 圆形按钮 | 241 |

差值约 12 级，用户截图里为 238 对 252。普通白色叠层在接近白色时只会叠加 `(255-C)×alpha`，白底上补不满；换成加色混合（`.plusLighter`）才能把整层抬高固定值。

另经探针确认：只有一个窗口能同时呈现 active 玻璃（key 或 main），所以两个圆形按钮无法靠窗口状态同时匹配外壳；也不能把一个窗口包住两个圆形按钮，窗口服务器会把中间透明间隙一起描成矩形阴影。

## 修改

`App/Sources/SurfaceWindow.swift`：

- 浅色不再画 1.5% 白色填充，改为 `Color.white.opacity(0.05).blendMode(.plusLighter)` 的加色叠层，随 `InactiveGlassTintView` 的显隐与外观切换。
- 深色保留原有 5% 白色透明填充；两套边缘高光描边不变。
- 叠层使用不参与命中测试的 `NSHostingView`，不影响按钮点击。

## 实际检查

- 独立 AppKit 探针（白底 / 中灰 / 黑底，key 与 main 对照）：加色叠层在白底把 241 抬到 252，与 key 外壳 253 相差 1 级；深色下普通填充保持原有效果。
- Debug `xcodebuild`（`-skipPackageUpdates`）：`BUILD SUCCEEDED`。
- `run-launcher-window-regression.py --accessories`：浅色与深色外观均通过。
- 未在真实桌面做最终肉眼截图：本机会话的第一个显示器被其他全屏窗口占用，启动器预览窗口落在屏幕外。
