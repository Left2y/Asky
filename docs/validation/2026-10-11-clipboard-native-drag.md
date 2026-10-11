# 剪贴板卡片原生拖拽与目标遮罩

## 修改

- 卡片通过 AppKit `mouseDown` / `mouseDragged` / `mouseUp` 接收输入，直接将拖动事件交给 `beginDraggingSession`，不再从 SwiftUI 手势更新中读取 `NSApp.currentEvent`。
- 卡片接受未激活窗口的首次点击，单击继续复制，移动达到 3pt 后启动拖拽。
- 拖拽开始时撤下外围点击关闭用的透明窗口，避免覆盖网页或其他应用的输入框；拖拽中失去键盘焦点不会销毁源视图。
- 拖拽成功关闭未固定面板；取消或目标拒绝时恢复外围关闭功能。拖拽期间不显示悬浮预览，操作始终为复制。
- 文字与图片载荷继续由 ToolService 的 `ClipboardAccess.dragItem` 提供。

## 已执行检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild`：通过，包含最终拖拽代码。
- `--drag` 原生窗口回归：真实鼠标按下、连续拖动、松开后，`NSTextView` 收到完整卡片文字，未固定面板关闭；重复执行通过。
- 原生窗口单击卡片后，回读状态显示“已复制”。
- Chrome `textarea`：真实跨应用拖入后，AX 回读输入值包含完整 `Paste anywhere, this is one example text`，网页 drop 事件回读 `text/plain` 与同样的文字。
- Chrome `contenteditable`：AX 回读输入值为完整卡片文字，drop 事件为 `text/plain`；源面板成功关闭。
- Chrome 图片接收区：跨应用拖入第二张图片卡片后，网页回读 `Files`，文件为 `.png`、`image/png`、911023 bytes；源面板在接受拖放后关闭。

## 验证限制

- 首次回归编译遇到 SDKROOT 指向 26.5 而 Xcode 产品使用 27.0 的冲突，清除 SDKROOT 后编译成功。
- 并行任务修改共享构建对象导致一次外部目标回归编译失败；后续复制 Debug 产品到忽略的 `build/ClipboardDragProducts`，使用独立回归程序验证。
- 最初外部拖放未被 Chrome 接收。补充 `CGWarpMouseCursorPosition` 使回归事件同步更新系统光标后通过；只投递合成拖动事件不足以验证跨应用拖放。此前失败没有记为通过。
- 微信、飞书实际输入框及图片接收未实测；Chrome 的文字和文件类型回读不等价于每个聊天客户端的验收。
- 关闭当前安装版进程后，启动最新 Debug 应用供现场试用；未打包或替换 `/Applications` 中的安装文件。

README 同步原生拖拽回归与人工预览命令；AGENTS.md 无架构、命令入口或持久规则变化。
