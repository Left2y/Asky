# 移除新结果展示后的额外收缩等待

用户进一步确认问题为“内容出来之后，有一点延迟才缩回去”。上一轮优化逐帧阴影与布局开销，没有移除 `ResultList` 在搜索结束后额外等待 200ms 的逻辑，因此没有解决这段可感知停顿。

本次只移除该 200ms 等待。搜索仍进行时保留列表高度，结果确认后立即更新目标高度，继续沿用原窗口弹簧动画。

实际验证：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：43 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --result-shrink`：浅色、深色通过。增加从新结果写入模型到面板开始实际收缩的测量与小于 150ms 的断言，覆盖原 200ms 等待；实测约 61ms、51ms。两种外观均经过 14 个中间收缩高度，窗口、输入框顶边和编辑器身份检查通过。
- 使用同次编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression` 分别运行 `--command-transition`、`--result-motion`：浅色、深色均通过。覆盖 sw 等待期间保留高度，以及展开、清空、反向切换、中断、重开和键盘选择。

延迟为真实窗口的程序采样结果，不是每台机器的固定性能承诺。验证日志位于忽略的 `build/shrink-delay-*.log`。
