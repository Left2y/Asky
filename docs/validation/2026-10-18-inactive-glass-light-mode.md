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

## 后续修复：按钮入场的暗色阶段

浅色外观下，圆形按钮窗口用窗口 alpha 淡入时会先处于半透明状态，透出后面的深色桌面，看起来像“闪一下暗色”。实测真实热键打开路径（⌘Space，浅色、深色壁纸）可复现：按钮在整段滑入过程中偏暗，落定后才变成最终磨砂外观。

曾先把浅色下的淡入压缩到弹簧前 1/2（约 70 ms），暗色阶段明显缩短，但按钮出现仍显得突然。

最终修改：原生玻璃下把两个圆形按钮窗口压到外壳窗口**下一层**（`order(.below, relativeTo:)`），按钮始终完全不透明，由收缩中的搜索框边缘自然遮住/露出，不再使用窗口 alpha 淡入。旧版兼容材质的搜索框不够不透明，遮不住下层按钮，因此仍保持“子窗口 + 淡入”。外壳变为 key 时补偿仍在此之前启用（见上一节）。

逐帧录屏确认：按钮从搜索框右端下方滑出，出现时就是最终磨砂外观，全程没有半透明发暗阶段；`--accessories` 浅色、深色回归通过（窗口计数断言改为按 52 pt 高度查找，不再依赖 `childWindows`）。

## 后续修复：按钮入场时亮度突跳

### 原因

`show()` 里第一次 `updateGlassAppearance(keyed: panel.isKeyWindow)` 执行时面板还不是 key，补偿层处于隐藏状态；约 50 ms 后面板成为 key 才启用补偿，此时圆形按钮的 alpha 入场动画已经开始了约 30 ms。

加色补偿使用 `CALayer` 合成滤镜。逐帧录屏并在筛选按钮内固定取样确认：补偿层的显隐若发生在窗口 alpha 动画进行中，滤镜只在动画落定后提交。表现为按钮在入场过程中没有提亮，落定那一帧突然增加约 10–12 级；关闭补偿的对照录屏里该落差消失。打字清空后重新入场的路径在动画开始前补偿已启用，没有该问题。

### 修改

`App/Sources/LauncherView.swift`：`show()` 在 `makeKeyAndOrderFront` 之后立即以 `keyed: true` 预备补偿，确保按钮窗口入场前补偿已启用。真实的 key 变化仍由 `becomeKey` / `resignKey` 更新；深色模式使用普通透明填充，不受该时序影响。

### 实际检查

- 浅色外观逐帧录屏，筛选按钮内部固定取样：修复前入场期间与落定后相差约 10.6 级且集中在单帧；修复后随窗口 alpha 平滑提亮，落定帧仅变化约 1 级。
- 打字清空后的重新入场（中灰背景探针）逐帧取样为 128 → 141 → 157 → 166 → 173 → 182，落定后保持 182–183，无台阶。
- `run-launcher-window-regression.py --accessories`：浅色、深色均通过（首轮在繁忙机器上筛选菜单 100 ms 断言偶发失败，重跑通过）。
- 预览录屏命令：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --accessories-preview --reveal-open
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --accessories-preview --reveal-motion
```

## 后续修复：按钮退场被外壳右缘切开

### 原因

上一节的入场方案让两个圆形按钮始终位于外壳窗口下一层。但打字消失时，外壳向右展开，它的圆角右缘会从按钮上方扫过：逐帧录屏可见左侧“固定”按钮先被切掉一块，再透过玻璃隐约残留，随后才淡出，看起来像卡顿和生硬裁切。入场时按钮从外壳下方滑出是期望效果，退场时同一个遮挡关系则相反。

### 修改

`App/Sources/LauncherView.swift`：

- `syncAccessoryStacking(above:)` 增加层级参数；原生玻璃下按钮默认仍在外壳下一层。
- `update(_:)` 在按钮由显示转为隐藏时，先把按钮窗口提到外壳**上一层**（`order(.above, relativeTo:)`），淡出不再被外壳圆角切割；重新显示时再放回下一层，保留“外壳收缩露出按钮”的入场效果。
- 旧版兼容材质仍使用子窗口 + 淡入淡出，不变。

### 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ... -skipPackageUpdates build`：`BUILD SUCCEEDED`
- `run-launcher-window-regression.py --accessories-preview --reveal-motion`：浅色、深色均通过；逐帧查看退场，左侧按钮完整圆形淡出，不再被外壳边缘切掉。
- `run-launcher-window-regression.py --accessories`：浅色、深色均通过。
- `cd Packages/KulaCore && swift test`：37 个测试通过。
- `run-launcher-window-regression.py` 默认窗口检查在繁忙机器上仍在 `model=afari` 的首字符断言处失败（既有已知偶发问题，与本次层级修改无关）。
