# sw 回车切换时的列表高度

问题：普通搜索输入 `sw` 后，回车进入窗口模式，`searchWindows()` 先发布空结果，再异步返回窗口。外层移除 `ResultList`，丢失其保留高度，导致面板先收起再展开。

修复：已有列表在搜索等待期间保持挂载，复用列表内部的高度保留逻辑。旧结果仍从模型移除，不可执行；搜索完成且无结果后正常移除列表。

实际执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：43 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --command-transition`：浅色、深色均通过。真实 LauncherPanel 在提交 `sw` 后、窗口枚举前的空结果等待期间保持原高度；reset 后恢复输入框高度。

其他检查：`--result-motion` 首次浅色通过（含本次切换断言），深色未通过已有的动画中间帧数量断言；直接重跑在初始展开的固定高度断言失败（430 vs 433）。该整套动效回归未记为通过。本次独立回归避免依赖这些固定动画采样，检查窗口模式切换的实际高度。

范围：程序调用正常 Return 提交路径并测量真实窗口；未进行物理键盘操作或逐帧视觉验收。测试日志保存在忽略的 `build/sw-return-*.log`。
