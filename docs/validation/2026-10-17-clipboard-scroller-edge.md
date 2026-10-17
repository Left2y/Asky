# 剪贴板详情滚动条贴边

详情区原先整体使用 24 pt 内边距，导致文本滚动条也向内缩进。改为给正文、图片、视频、文件和信息区分别设置水平留白，文本滚动视口延伸至右侧边缘。正文左右保持 24 pt 留白，覆盖此前仅为文本右侧追加 16 pt 的处理；信息区仍固定在下方。

实际执行：

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，37 项 Swift Testing 测试。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：最终通过。新增真实 NSScrollView 几何检查，视口右边缘与窗口右边缘误差小于 1 pt；长文本超过视口且可滚动。原有切换、筛选、复制、置顶和设置持久化检查通过。
- 初次回归在截图时窗口内容已释放而中断；直接重跑通过，补充系统截图后完整命令再次通过。
- 已查看系统窗口截图 `build/clipboard-layout-list-long-text-native.png`，可见原生滚动条贴近右边缘，正文与信息区保留留白。
- `git diff --check`：通过。截图和回归产物沿用现有 `build/` 忽略规则。

README: unchanged；局部布局修复没有改变用法和命令。AGENTS.md: unchanged；没有新增架构、子项目或持久开发规则。

未替换已安装应用，未发布版本。
