# 启动器首次显示偶发白块调查

## 结论与范围

用户反馈 Debug App 重建或更新后，启动器左下方极低概率闪过白色矩形。本次没有捕获异常帧，**根因尚未确认，也没有宣称修复**。保持产品代码不变。

当前优先调查的是首帧布局与玻璃合成的时序。仅凭代码结构差异不能排除系统输入法浮层、其他窗口或 WindowServer 合成；也不能认定阴影、白色提亮层就是原因。

## tinycast 对照

实际下载并检查 tinycast 提交 `6029038ff3b2043077b7105286152d99a893047a`：

- [PaletteWindowController](https://github.com/abue-ammar/tinycast/blob/6029038ff3b2043077b7105286152d99a893047a/Tinycast/Palette/PaletteWindowController.swift) 的 `show()` 先定位、确定收起尺寸、离屏布局，再显示；`ensurePanel()` 复用已有窗口，普通 `hide()` 只将窗口移出屏幕，不清空主内容树。
- [PalettePanel](https://github.com/abue-ammar/tinycast/blob/6029038ff3b2043077b7105286152d99a893047a/Tinycast/Palette/PalettePanel.swift) 将 `NSHostingView` 直接设为窗口内容。玻璃在 [RootPaletteView](https://github.com/abue-ammar/tinycast/blob/6029038ff3b2043077b7105286152d99a893047a/Tinycast/Palette/RootPaletteView.swift) 中作为背景，随窗口布局尺寸。
- Asky 在 `LauncherController.hide()` 释放内容树；重新显示时重建 `NSHostingView`、玻璃和包装层。Asky 已有显示前布局、圆角同步、`displayIfNeeded()` 和禁用默认窗口动画的处理，不能再把同样处理当作新修复。
- tinycast 的实现提供可比较的生命周期，不能据此证明它没有相同闪块。不能直接照搬保留整棵视图树的做法，因为 Asky 现有资源生命周期要求隐藏后释放内容与结果。

## 动态探查

在 `/tmp/asky-flash-diagnosis/` 复制并扩展现有 `--first-presentation` 测试，不改项目 Swift 源文件。沿用原生回归 runner 的编译及资源复制流程，链接现有 Debug 依赖产物，使用当前 App 源码；这不是一次完整 App 构建或安装更新验证。

增加显示刚返回及第一次事件循环让出后的视图树、尺寸、隐藏状态和编辑器背景记录。浅色、深色各重建 20 次，几何、裁剪、编辑器、重复打开和隐藏释放断言完成。日志中的固定测试描述也同步为 20 次。

观察：

- 窗口、玻璃和内容容器都是 `640 × 52`；主 `NSHostingView` 是 `(0, -381, 640, 433)`。这是既有的顶部锚定画布，不等于已经发现越界白块。
- 首次 `show()` 返回时，编辑器的 `_NSTextSelectionView`、`_NSTextRenderingSurfacesGroupView`、`_NSTextContentView` 尺寸仍为零；第一次让出事件循环后成为 `563 × 19`。显示前的布局与绘制调用并没有让所有内部布局在显示前结束，但这些私有视图延迟布局是否造成白块仍需像素证据。
- `InactiveGlassTintView` 在两个外观的这两次采样中都为隐藏状态，其白色 `AdditiveWhiteLift` 宿主尺寸为 `640 × 52`，没有观察到左下方可见的独立白矩形。
- 编辑器 `drawsBackground == false`，采样中的窗口框架背景 alpha 为零；没有观察到普通文本输入白底。

探查命令：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 /tmp/asky-flash-diagnosis/run.py --first-presentation
```

临时工具不是项目稳定入口，不加入 README。首轮临时脚本因复制后的 `#filePath` 改变工作目录，截图无法写入预期相对路径；`screencapture` 仍返回 0，因此该轮截图不能记为成功。后续将工作目录显式设回项目根、截图目标改为临时目录的绝对路径，并检查图片实际存在。第二轮退出码为 0，浅色、深色各 20 次断言通过；两张 PNG 均已实际生成并查看，未见白矩形。此结果只覆盖截图时刻。

## 验证边界与后续

- 视图树断言不证明屏幕合成帧正常。约 80 ms 后的静态窗口截图也不能排除更早的一帧白块。
- 同一测试进程内的 40 次重建不是 40 次真实 App 冷启动，没有覆盖安装更新后的第一次启动。
- 下一步应在真实 Debug 冷启动及更新首次启动前开始连续录制，同时记录窗口显示、首个布局、编辑器取得焦点与新窗口出现的时间；捕获异常后用白块位置、大小和所属窗口区分玻璃、编辑器或系统浮层。
- 若证据指向玻璃/布局初始化，再比较最小改动的 A/B：避免为主启动器创建永不启用的提亮宿主，或在最终尺寸完成内容与玻璃初始化；无复现基线时不能将这些改动宣布为修复。不加固定延迟掩盖现象，不改变既有玻璃外观或资源释放规则。
