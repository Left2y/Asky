# 搜索结果入场动画验证

日期：2026-10-18

## 改动

- 搜索玻璃外壳沿固定顶边向下展开，复用 SurfaceSpring，以 response 0.18、damping 1 保持无回弹；结果批次从当前高度继续。
- ResultList 首次插入时 180 ms 淡入并从下方 6 pt 归位；保留列表时的查询更新、结果批次、方向键选择不重复入场。
- 清空直接收起，隐藏停止显示链路；减少动态效果时直接调整窗口，仅保留 100 ms 淡入。减少动态效果分支已检查代码，本次未切换用户系统设置进行实测。

## 实际执行

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild`：BUILD SUCCEEDED，日志 `/tmp/asky-result-motion-build.log`。
- KulaCore `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：13 次 Swift Testing 运行合计 262 tests 通过，日志 `/tmp/asky-result-motion-core.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --result-motion`：浅色、深色通过，分别采到 20、19 个中间高度样本；最终高度 433 pt，输入框屏幕位置偏差最多 1 pt；方向键即时选择、编辑器身份、清空、中断、隐藏再显示通过。日志 `/tmp/asky-result-motion-native.log`。
- 同一新编译原生回归二进制 `--accessories`：浅色、深色通过，包括筛选隔离、输入位置、固定、失焦、Escape 与重复 show。日志 `/tmp/asky-result-motion-accessories.log`。
- 检视实际窗口截图：`build/launcher-result-motion-NSAppearanceNameAqua.png` 与 `build/launcher-result-motion-NSAppearanceNameDarkAqua.png`，圆角、玻璃、输入与结果布局正常。测试行使用占位文件图标。
- 完整 LauncherWindow 回归：实际滚轮事件投递、键盘滚动与连续输入位置检查通过；`slow pending search must retain the result footprint` 未通过，不能记为完整回归通过。日志 `/tmp/asky-result-motion-existing.log`。

对照检查：将修改前 App 源码与 Debug products 复制到 `/tmp/` 隔离编译。对照程序在系统滚动背景检查中因 `scrollView(in: content)!` 为 nil 崩溃，未能运行到慢搜索高度检查，因此不能断言此项是已有失败。编译期间也观察到并发源码与 ToolService.o 更新，首次两次对照编译因输入被修改而停止；最终隔离复制后编译完成。对照日志 `/tmp/asky-result-motion-baseline.log`。

## 工作区与维护

测试与构建通过时的 App 为本次动画版本。随后另有并发文件夹导航改动进入工作区；不将其纳入本次动画提交，也不将先前检查当作并发改动后的整体验收。生成截图与回归产物由现有 `build/` 忽略规则覆盖；临时日志与隔离基线比较位于 `/tmp/`。

README 中英文同步动效说明与回归命令；AGENTS.md 无需变更，现有 App 与 ToolService 边界、构建和验证规则仍适用。
