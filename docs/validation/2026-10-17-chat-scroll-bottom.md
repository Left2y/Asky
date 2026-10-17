# AI 对话回到底部按钮

- 对话离开底部时，在输入框上方 8pt 居中显示 32pt 圆形玻璃按钮，使用旋转后的 MingCute 向上箭头作为向下箭头；复用现有圆形玻璃按钮样式。
- 根据 `contentOffset.y + containerSize.height` 与 `contentSize.height + contentInsets.bottom` 判断底部，允许 1pt 浮点误差；点击使用 `ScrollPosition.scrollTo(edge: .bottom)`，覆盖正文底部留白。
- 浏览历史消息时不因消息或流式文本更新强制跳到底部；开启减少动态效果后，点击立即滚到底部。

## 已运行检查

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，Swift Testing 37 项、9 个 suite。
- 原生回归入口：Debug 构建后，`python3 App/Tests/run-agent-reply-regression.py --scroll-preview`，生成 24 条本地测试消息，不调用模型或真实工具。

- 原生窗口实测（24 条消息，720×640）：初始滚动条值为 1，按钮隐藏；通过滚动列表回到顶部后按钮出现，截图确认按钮下缘距输入框上缘 16 个 Retina 像素（8pt）；点击按钮后再次读取窗口，滚动条值为 1，第 24 条消息可见，按钮隐藏。
- 原生 AgentReply 模型回归：通过（澄清持久化、完成回复、取消、耗时、新对话清理与历史保留）。
- 为避免同一工作区并行修改导致 Swift 编译中断，最终原生回归从 `build/scroll-source-snapshot/` 中冻结的源码编译，以独立 bundle ID 运行；构建和回归产物均由现有 `build/` 忽略规则覆盖。

README 中英同步补充使用行为；AGENTS.md 无需改变，未引入新的架构边界或开发命令。
