# 别名弹窗移除背景遮罩

- 将 `AliasSettings` 弹窗后方的 `Color.black.opacity(0.18)` 改为 `Color.clear`，添加与编辑别名均不再绘制灰色遮罩。
- 保留透明层的点击拦截，弹窗内容、玻璃表面、关闭与保存逻辑不变。
- 已运行 `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，退出码 0。
- 已运行 `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令，构建成功。
- 尝试启动新构建并使用 Orca computer-use 核验；新进程未提供可操作的设置窗口，实际弹窗视觉与点击交互尚未核验。
- README 与 AGENTS.md 无需更新：本次仅移除局部视觉遮罩，没有新增命令或改变使用流程与架构约束。
