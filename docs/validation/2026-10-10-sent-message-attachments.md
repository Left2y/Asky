# 已发送消息附件展示

## 修复

原先附件只进入 AgentRequest，原生消息记录仅有文字，发送后输入区清空即不再显示附件。现在用户消息保存有序的 AttachmentRef 列表，并在文字气泡上方靠右显示 52 pt 图片缩略图或文件名称／大小卡片；已发送卡片无删除按钮。超宽附件行可横向滚动。缩略图经 ToolService 按需在后台生成，不保存原图到消息对象。

SQLite v2 为 messages 增加 attachments_json，旧消息默认为空数组。新消息即时展示、分页加载和历史重开共用同一数据。消息保存失败时保留输入及附件，并显示失败原因。旧版没有保存的附件引用无法自动恢复。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：135 个测试通过，包含旧数据库迁移、附件顺序与完整元数据、磁盘重开、分页、检索与消息删除。
- `xcodegen generate` 与 README 中的 Debug xcodebuild 命令：通过。
- `python3 App/Tests/run-agent-reply-regression.py`：通过，覆盖消息恢复与重新打开后附件顺序，并保留原有回复回归。
- 使用 `--attachment-preview <图片路径>` 打开当前源码编译的原生对话窗口（独立临时数据库），通过 computer-use 截图及可访问性树确认图片缩略图、PRD-Spotlight.md 名称与大小、文字气泡上下排列并右对齐；已发送卡片没有删除按钮。关闭验证进程后另行运行非预览回归，退出码 0。

## 范围

没有调用模型，没有修改个人会话，没有打包 Release 或安装。视觉验证覆盖一张图片和一个文件；超宽附件滚动未进行实际交互验收。现有附件文件清理策略未在本次修改中扩展。

README: updated，中英文同步已发送附件与旧消息兼容说明。
AGENTS.md: unchanged，沿用既有 Swift 测试、App 构建与 ToolService 边界。
