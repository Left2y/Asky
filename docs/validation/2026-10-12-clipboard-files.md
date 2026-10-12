# 剪贴板文件识别与原生拖出

## 修改

- ToolService 优先读取真实 `public.file-url` / `NSFilenamesPboardType`，监听器将文件选择记录为文件，避免 Finder 附带文件名被当成文字。普通 `file://` 文字仍按文字处理，敏感/临时标记继续排除。
- SQLite v5 增加整组文件路径；兼容已有单文件记录。文件名可检索，卡片显示文件图标，复制与拖出保持所有文件地址，操作类型为复制。
- 原文件不可读或已删除时，复制/拖出失败，不清空现有剪贴板，也不静默丢掉组内文件。
- 文件历史只保存原路径，不备份文件内容；删除记录和过期清理不会返回原文件路径供删除。图片清理逻辑保留。
- 启动器的历史复制也使用 ToolService，避免文件记录退化为文字动作。

## 已执行验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过，含文件+目录、多文件持久化、复制/拖出、失效保护、旧格式与敏感标记、文件清理保护和普通 URL 文字检查。
- `xcodegen generate`：通过。
- README Debug `xcodebuild`：通过。
- `env -u SDKROOT DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --files`：监听器读取完整文件选择，存储和复制回读一致；真实光标按下、拖动、松开后，原生接收窗口收到两份文件 URL，内容逐字节一致，未固定源面板关闭。
- 同一新编译原生窗口以 `ASKY_CLIPBOARD_DROP_POINT=850,350` 拖至真实 Finder：源面板成功关闭，Finder 在 `build/clipboard-file-source` 接收到 `复制文件.txt` 与 `second.pdf`，内容分别为 27 / 21 bytes，与生成内容完全一致；AX 与截图可见两份文件。
- 新编译回归程序 `--drag`：原有文字拖出与面板关闭通过。
- 最新 Debug 主应用已启动；运行路径为 `build/DerivedData/Build/Products/Debug/Asky.app`。同一工作区的其他任务也在启动应用，当前前台实例可能随后被其更换。

## 限制与执行记录

- 旧版已经只记为文件名的文字记录无法反推原路径，需要重新复制原文件。
- 文件移动、删除或失去读取权限后需重新复制；微信、飞书等聊天客户端未实测，不从 Finder 接收推断其行为。
- 尝试通过 Orca 对 Finder 执行复制快捷键受到 `window_not_focused` 阻挡，未记为通过；文件输入监听已在原生程序中使用系统剪贴板验证。
- 首次构建遇到其他设置页正在修改导致的 `extra argument images`；后续构建通过。一次回归编译期间修改测试源文件导致 input modified，重新编译后通过。
- 构建/测试日志、测试文件、截图与回归程序沿用 `.gitignore` 的 `build/` 规则，不进入提交。
- README 中英文同步能力、原路径限制与 `--files` 命令；AGENTS.md 无持久命令入口、架构边界或子项目变化。
