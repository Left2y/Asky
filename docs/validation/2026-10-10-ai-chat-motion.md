# AI 对话导航动画验证

日期：2026-10-10

## 改动

- 历史页进入与返回使用 240 ms easeInOut 淡化和 16 pt 横向位移，标题与搜索栏同步淡化，头部高度平滑变化。
- 新建和恢复对话使用内容身份区分，正文/空状态使用淡化与 8 pt 纵向位移；新建对话保留输入框的视图身份。
- Transcript 使用当前渲染的数据值快照，避免清空模型时退出中的旧消息立即消失；消息操作仍由现有模型处理。
- 恢复 Transcript 时定位到末尾。流式增量不会触发页面导航动画。
- 空白页问候语按每字符 38 ms 出现，透明的剩余字符保留最终宽度，避免居中位置随文字增长移动。任务在离开视图时取消；辅助功能读取完整句子。
- Reduce Motion 直接显示完整问候语，并使用 150 ms 淡化，并移除过渡中的位移。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：140 项测试、28 个套件通过。第一次未指定 Xcode 工具链时因缺少 Testing 模块失败；切换工具链后通过。
- `python3 App/Tests/run-agent-reply-regression.py` 编译完成；复用正在运行的预览 bundle 时，原路径启动被 SIGKILL（未单独定位系统终止原因）。随后直接运行其新编译产物 `build/agent-reply-regression`：回复持久化、澄清合并、取消、耗时和附件历史回归全部通过。将测试 bundle 复制至独立路径并重新签名后，最终原生预览正常启动。
- 最终含逐字问候版本：将现有回归脚本仅在 `build/` 中改用独立产物路径后运行，回复与附件回归通过。使用独立 bundle 标识的原生预览，录屏逐帧确认 `He` → `Hey，` → `Hey，wh` → 完整句子，文字左边界稳定，旧回复退出时淡出、输入框保持原位。
- 使用该回归工具的 `--preview` 打开实际 AgentView 原生窗口，以临时数据库生成会话，未调用模型或读取个人对话。
- Orca 原生 UI 检查：历史列表、恢复回复内容、新建空对话后的标题、问候和输入框均正常显示。
- `screencapture` 录制原生窗口，并通过 ffmpeg 提取帧：进入历史及历史页开启新对话存在多帧淡化和位移过程。录屏和帧图位于被忽略的 `build/ai-chat-motion-*`，不纳入提交。

## 验证范围

录屏检查的是标准动态效果路径。Reduce Motion 分支已编译，但没有修改系统设置进行实机验收。未进行 Release 打包或安装。
