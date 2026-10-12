# 最后一项滚动顿挫修复

上一版使用单独的底部锚点并强制 `.bottom` 对齐。此次将 12 pt 底部留白放入最后一个结果的滚动目标范围，移除底部锚点和最后一项的特殊滚动分支，统一使用 ScrollViewReader 的最小可见滚动。

实际执行：

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过，日志 `build/launcher-bottom-smooth-swift.log`。
- `xcodegen generate` 与 README Debug xcodebuild：通过，日志 `build/launcher-bottom-smooth-build.log`。
- `python3 App/Tests/run-launcher-window-regression.py --bottom-clearance`：亮暗模式通过。新增末项返回时位移上限与底部留白断言；包含列表滚轮、首尾键盘导航和输入焦点检查。日志 `build/launcher-bottom-smooth-native.log`。
- 真实 UI：关闭旧 Asky 进程后启动新 Debug bundle，确认 PID 98378 的可执行路径。输入 kimi，选到末项后按 Up，再按 Down；前后截图中的列表与窗口位置一致，仅 GitHub 与询问 AI 的选中背景切换，末项底部仍有 12 pt 留白。此证据确认消除了这一步的额外位置跳动，不作为帧耗时测量。
- 本次未重跑完整系统事件投递与异步搜索时序回归；上一轮的失败记录保留在 `2026-10-12-launcher-bottom-clearance.md`。

README: unchanged：已有专项命令及其覆盖说明仍准确。

AGENTS.md: unchanged：现有开发流程和架构边界未变化。

构建日志和回归产物复用已有 `build/` 忽略规则。
