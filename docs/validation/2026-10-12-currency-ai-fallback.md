# 汇率加载期间 AI 兜底闪烁修复

## 原因与变更

汇率使用独立异步任务，加载期间 `isSearching` 为 true，但 `remainingSearchProviders` 为 0。此前 `publish()` 只检查普通搜索 provider 数量，导致汇率结果返回前出现 AI-only 列表。

改为使用整体 `isSearching` 状态决定是否允许空结果的 AI 兜底。已有本地结果时保留原有行为；汇率加载时等待结果，加载结束后发布汇率结果。未修改汇率计算、网络或缓存策略。

原生计算/汇率回归新增加载初始状态、持续等待期间无 AI、Return 不误提交 AI、完成后汇率优先检查，覆盖 `1美元`、`100人民币`、`100 USD CNY`。测试窗口固定，避免桌面焦点变化取消查询。

## 实际验证

- 修复前新增回归失败：`currency loading must not publish an AI-only fallback`，确认可复现。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-launcher-calculation-regression.py`：最终浅色、深色均通过。早期未固定窗口的尝试遇到 calculator completion / currency result 检查失败，最终固定测试窗口后完整命令通过。
- `python3 App/Tests/run-launcher-window-regression.py --ai-routing`：浅色、深色均通过，覆盖混合速度 provider、保留命中、无匹配 AI 兜底、Return、取消旧批次和显式范围。

日志与窗口缓存截图位于已忽略的 `build/`。已启动新构建的 Debug 应用，但 Orca 对该进程返回 `window_not_found`；视图缓存截图背景不完整，不能作为真实窗口逐帧视觉验收。未替换 `/Applications/Asky.app`，未打包或发布。

## 文档检查

- README: unchanged — 修复既有行为，不改变能力、使用方法或开发命令；中英文回归命令已包含本次检查。
- AGENTS.md: unchanged — 未改变模块边界、开发流程或持久指导。
