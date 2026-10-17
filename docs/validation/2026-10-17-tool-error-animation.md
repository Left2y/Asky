# 工具错误详情展开与收起动画

日期：2026-10-17。

- 错误详情高度与透明度使用 0.2 秒 easeInOut 过渡，箭头在同一事务内旋转 90°。
- 保留详情的自然文字高度，在外层裁剪高度动画，避免过渡时文字被压缩为省略号。收起时高度为零，8 pt 顶部间距包含在裁剪区域内，不留额外空白。
- 系统“减少动态效果”启用时使用无动画事务；收起的错误详情从辅助功能树隐藏。该系统设置分支仅作代码检查，未修改用户系统设置验证。
- README 中英文同步说明交互；AGENTS.md 无需改动，本次未引入新的开发命令或架构边界。

已运行：

- `xcodegen generate` 通过。
- README 中完整 Xcode Debug 构建命令通过，最终代码再次构建成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（KulaCore）：258 项 Swift Testing 测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --tool-preview`：最终代码编译、签名并启动原生窗口，预览前的回复、附件、新对话与 12 条工具记录断言通过。首次编译因本次继续修改 AgentView.swift 被编译器中止，固定代码后重新执行成功。
- 使用 computer-use 检查本次新进程 PID 47241：点击错误工具按钮，collapsed → expanded → collapsed → expanded；详情在辅助功能树中随状态显示/隐藏。截图捕获到展开中的部分高度与旋转中箭头，稳定后两行错误完整显示、箭头向下，后续工具行随详情高度下移。
- `git diff --check` 通过。

日志、截图状态 JSON、回归 bundle 和编译产物沿用已有 `build/` 忽略规则，不提交。原有预览进程未改动。
