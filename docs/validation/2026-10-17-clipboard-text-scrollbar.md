# 剪贴板长文本滚动条间距

列表右侧长文本预览在滚动内容内部预留 16pt 右侧空间，使文本在滚动条左侧换行，避免浮动滚动条覆盖文字。

## 实际验证

- `xcodegen generate` 和 README 的 Debug `xcodebuild`：通过。
- `Packages/KulaCore` 使用 Xcode 工具链执行 `swift test`：259 项通过。
- README 的 `run-clipboard-regression.py --layouts`：首次因并行构建修改 `Theme.o` 中断，重试通过。
- 查看最新 `build/clipboard-layout-list-text.png`：长文本预览、底部来源和时间布局正常。另以进程参数 `-AppleShowScrollBars Always` 运行现有布局回归，通过；未改写系统偏好。

README: unchanged；AGENTS.md: unchanged。本次局部显示修复不改变使用方式、命令或架构约定。保留已有并行改动，仅提交滚动间距与本记录。回归产物沿用现有 `build/` 忽略规则。
