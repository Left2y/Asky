# 窗口菜单全屏切换

日期：2026-10-23。

## 行为

- 移除窗口菜单的“退出应用”；“进入全屏／退出全屏”位于上方，红色“关闭窗口”固定在底部。
- 打开菜单时读取目标窗口的全屏状态；不支持可写全屏属性时只提供关闭操作。
- 全屏切换默认 `⌃⌘ F`，仅对选中的应用窗口结果生效。“设置 › 快捷键 › 启动器”中的“进入或退出全屏”支持录制、冲突检查、保存与恢复默认。
- 经 ToolService 校验精确 AX 窗口身份，执行显式进入／退出动作，并在动画过渡后回读；不按应用名、标题或当前前台窗口猜测目标。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData-fullscreen build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。首轮因缺少 AgentRuntime 编译产物而失败；按 README 执行 `npm ci && npm run build` 后重跑通过。
- `run-settings-regression.py --local-shortcuts`：通过，覆盖默认绑定、自定义绑定持久化、同作用域冲突拒绝、原生快捷键录制与恢复默认。
- `run-launcher-window-regression.py --window-search`：通过，覆盖进入／退出全屏文案、关闭操作在底部、仅关闭为红色、不支持全屏时隐藏该动作、⌘K／方向键／Esc；已查看浅深色真实窗口截图，确认快捷键标签和顺序。
- `run-launcher-window-regression.py --window-search-live`：通过。两个同标题原生窗口保持独立，切换及恢复最小化窗口正常；指定窗口进入／退出全屏且另一个窗口保持窗口化；启动器默认快捷键进入、自定义快捷键退出，旧绑定停用；关闭目标后拒绝再次关闭及全屏操作。

为避开并行插件及显示器功能修改，最终原生回归使用 `/tmp/asky-fullscreen-verification` 中的 App 源码快照，并设置 `ASKY_DERIVED_DATA` 指向上述独立构建目录。源码快照包含本次全屏及快捷键变更。未把并行功能的验证算作本次结果。

## 边界

真实窗口测试在辅助功能已授权的原生测试应用中运行，快捷键通过 NSEvent 走启动器实际分发路径；未验证物理键盘输入，也未逐个验证第三方应用。进入全屏时测试应用暂时从 AX 窗口列表隐藏其他窗口，因此用测试应用自身的 NSWindow 状态核对同名窗口没有被误操作，不将暂时隐藏误判为目标已关闭。

README 中英文已同步。AGENTS.md 的架构边界、命令和指南入口无需变更。构建、依赖及回归产物沿用已有忽略规则。
