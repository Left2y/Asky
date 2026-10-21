# 启动器首次显示前完成布局与绘制

用户反馈：Debug 或更新后的应用首次打开搜索时，偶尔先闪过直角方框，然后搜索框才出现，持续时间不足以截图。

代码检查发现 `LauncherController.show()` 安装新 SwiftUI/玻璃树、设置窗口位置后立即调用 `makeKeyAndOrderFront`，没有主动完成整个窗口视图树的首帧布局与绘制。此路径是本次修复目标，尚未通过捕获异常帧证明它就是用户所见现象的根因。

修改：启动器禁用 AppKit 默认窗口出场动画；显示前完成 frame/content 视图布局，重新同步圆角裁剪并调用 `displayIfNeeded()`，然后才将窗口置前。保留结果展开动画、系统阴影和隐藏时释放视图树的行为。

实际运行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志 `build/first-presentation-build.log`。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，日志 `/tmp/asky-first-presentation-core-tests.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --first-presentation`：通过。浅色、深色各重建并显示 10 次，检查同步初始尺寸、内容及 frame 圆角裁剪、输入编辑器、重复 show 与隐藏后释放树。日志 `build/first-presentation-regression.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --result-motion`：通过。浅色/深色分别获得 23/19 个中间尺寸样本，输入框顶边漂移为 0 pt，键盘、清空、打断与重开检查通过。日志 `build/first-presentation-motion.log`。
- 已查看真实窗口截图 `build/launcher-first-presentation-NSAppearanceNameAqua.png` 与 `build/launcher-first-presentation-NSAppearanceNameDarkAqua.png`：胶囊圆角完整，搜索图标、占位文字和插入光标正常。

限制：截图位于显示后约 80 ms，不能证明更早的合成帧无闪框。本轮没有捕获修改前的异常帧，也没有执行安装更新后的首次启动；偶发问题是否消失仍需后续冷启动实际观察。未发布新版本，未替换正在运行的正式版。

README 与 AGENTS.md 不变：本次只调整既有窗口的显示准备过程，沿用已有构建、测试、玻璃结构与系统访问边界。
