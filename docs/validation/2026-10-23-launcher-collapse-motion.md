# 搜索清空后的收起动画

清空搜索后，启动器外壳使用与展开相同的 `SurfaceSpring`（response 0.18、damping 1）平滑收起到 52 pt。搜索框顶边保持固定；收起期间重新输入从当前高度转向展开。隐藏仍停止动画，减少动态效果仍直接切换尺寸。

## 已执行验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --result-motion`：Aqua / DarkAqua 均通过。实际窗口展开分别采样到 21 / 20 个中间帧，收起均有 13 个不同的中间高度，输入框顶边位移为 0；键盘选择、编辑器保留、收起途中重新输入、展开途中清空、隐藏重开均通过。已检查浅色窗口截图；动画证据来自实际窗口逐帧尺寸采样，未进行真人键盘手动验收。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：未全通过。`PluginTests.nativeWorkerRoundTripAndPolicy()` 在 `PluginTests.swift:110–112` 的完成状态及输出/回读断言共报 4 个问题，日志同时出现 `sandbox_extension_consume failed: 1 (Operation not permitted)`。本次未改动插件或 KulaCore。
- `git diff --check`：通过。

减少动态效果分支保留原逻辑，本次未切换系统设置单独验证。

README 无需修改：这是现有搜索交互的小修复，使用方式与构建命令均未变化。设计系统已同步收起行为。AGENTS.md 无需修改：没有新增架构边界、命令或持久开发约定。构建、回归产物沿用现有 `build/` 和 `Packages/KulaCore/.build/` 忽略规则。
