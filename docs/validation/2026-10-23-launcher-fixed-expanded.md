# 启动器展开后固定高度

按用户确认，启动器首次出现结果或进入搜索模式后展开至固定高度：默认 433 pt（52 pt 输入区、1 pt 分隔线、380 pt 结果区），小屏幕按当前显示器可用空间限制。同一次展示期间，单条或多条结果、异步加载、模式切换、空结果和清空输入均不缩放外壳；隐藏释放视图，再次打开恢复单行。列表在固定结果区内滚动，主操作与更多菜单保持底部位置。

删除按结果数量计算列表高度、保留旧高度及等待缩短的逻辑。计算结果的操作区也对齐固定面板底部。README 中英文、PRD、设计系统与开发检查入口同步更新。

实际执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：43 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --fixed-expanded`：浅色、深色通过，使用真实 LauncherPanel 检查单条、多条、空输入、计算、sw 加载、输入框位置与编辑器身份、关闭后重开。首次运行在单条结果的固定等待断言失败；补充实际几何信息后重跑及使用同一编译产物重复检查均通过，未将该检查视为冷启动耗时承诺。
- 使用同次编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression` 分别执行 `--result-motion`、`--command-transition`、`--compact-results`、`--action-bar`：浅色、深色均通过，覆盖首次展开、固定高度、焦点、菜单、最后一项及计算操作区。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --bottom-clearance`：最终浅色、深色通过。检查 640 × 433 pt 面板的屏幕内定位、鼠标/精确滚动、正反方向、输入区滚动路由、上下键与列表底部留白。

边界测试首次在键盘选择断言失败：测试在滚轮检查后直接调用文本代理，代理读取的 `NSApp.currentEvent` 仍是滚轮事件。改为向 NSApplication 投递真实方向键事件，测试再运行通过；产品键盘派发未改动。

已查看实际浅色/深色单结果窗口截图和浅色计算截图，确认固定空白区域、圆角、底部操作区；未进行物理键盘或逐帧视频验收。截图：`build/launcher-fixed-expanded-NSAppearanceNameAqua.png`、`build/launcher-fixed-expanded-NSAppearanceNameDarkAqua.png`、`build/launcher-actions-NSAppearanceNameAqua-calculation.png`。日志和参考源码沿用 `build/` 忽略规则。
