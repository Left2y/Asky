# 启动器收缩更新同步

用户反馈列表缩短时掉帧、闪动。检查发现窗口动画每一帧均重复设置玻璃与内容的圆角，并显式调用 `invalidateShadow()`。圆角已经在首次展示前设置，窗口尺寸变化本身由 AppKit 管理阴影。

本次删除逐帧的重复样式设置与显式阴影失效；将窗口尺寸、玻璃祖先布局和 hosting 布局放入禁用隐式动画的同一 Core Animation 事务。保留现有显示链路弹簧、整数高度、固定顶边、搜索等待期间的列表高度与系统阴影。不强制逐帧同步绘制。

实际检查：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `Packages/KulaCore` 中执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：43 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --result-shrink`：浅色与深色通过。多行结果替换为单个 AI 候选（不调用模型），验证单向收缩、窗口和输入框顶边固定、玻璃尺寸与窗口同步、面板可见性及编辑器身份保持；分别观察到 14、15 个不同收缩高度。
- 使用同次编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --command-transition`：浅色、深色通过。
- 使用同次编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --result-motion`：浅色、深色通过，包括展开、清空、反向切换、中断、重开与键盘选择；两种外观均观测到 21 个展开中间采样、13 个收缩中间高度，输入框偏移为 0。

边界：收缩专项的最大主线程采样间隔约为浅色 48ms、深色 39ms，因此以上结果证明几何连续性与交互状态，不能证明所有帧均按显示器刷新率提交，也不能替代用户对实际玻璃闪动的视觉验收。日志位于忽略的 `build/shrink-*.log`。
