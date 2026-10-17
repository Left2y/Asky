# 启动器悬浮操作区

## 行为与结构

- 常用操作收在左下方的玻璃胶囊中，右下方为独立的圆形“更多操作”按钮，两者之间弹性留白；无固定底栏或横向分隔线。
- 两个浮动表面分别使用与外形同尺寸的 `SurfacePanel`、AI 对话按钮同款 `nativeGlassBackground`，不叠加 AppKit 玻璃层；内部控件关闭窗口阴影、不额外描边；沿用项目的旧系统与辅助功能材质回退。
- 列表底部 68 pt 渐隐，内容可从浮动控件后方滚过；最后一条结果的滚动目标包含底部留白。
- 应用、文件显示打开与访达操作，菜单收纳拷贝路径；链接显示打开或搜索，菜单提供拷贝链接；计算显示拷贝结果。无次要操作时隐藏菜单按钮。
- 点击菜单按钮或按 ⌘K 打开原生菜单；既有可配置的访达与路径快捷键优先。菜单追踪期间交由系统处理点击，避免窗口外点击拦截层提前关闭启动器。
- 打开、访达显示与复制经 ToolService 执行。

## 已执行检查

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：236 项测试、47 个 suite 通过。
- `git diff --check`：通过。

- `python3 App/Tests/run-launcher-window-regression.py --actions`：最终玻璃实现的浅色、深色回归通过，覆盖左右定位、中间留白、无额外窗口阴影、无第二层 AppKit 玻璃、⌘K 菜单追踪、拷贝路径与链接、选择切换、计算动作。
- 已构建的原生回归程序 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --bottom-clearance`：浅色、深色均通过，覆盖行/精确滚动、正反滚动、焦点保持、键盘选择与末行底部留白。
- 完整窗口回归程序的一次运行未通过 `system wheel must reach launcher`：系统注入滚轮后，前景列表位置保持 0，背景保持 200；该系统事件投递项不记为通过。针对本次变更的上述菜单与滚动留白回归通过。

视觉对照已按用户反馈修正：从固定底栏改为悬浮、左侧胶囊与右侧圆按钮、底部渐隐，最后将控件材质统一到 AI 对话按钮的同一 `nativeGlassBackground`，禁用内部表面的额外窗口阴影。

构建与回归编译存在 Xcode 模拟器组件和已有 Swift 并发警告；macOS App 构建成功。测试生成的应用及截图保留在已忽略的 `build/` 中，不进入源码提交。未打包、发布或替换 `/Applications` 中的应用。
