# 正式 Asky 面板拖放验收与运行实例核对

## 发现

- 用户报告仍不能拖放后，现场同时存在 Debug 修复版和 `/Applications/Asky.app` 0.0.14。二者二进制 SHA-256 不同，且都使用同一 bundle ID、数据目录和快捷键。
- 用户设置的剪贴板快捷键实际为 Ctrl+Shift+C，不是 README 默认组合键。
- v0.0.14 源码中的 ClipboardAccess.copy/dragItem 没有文件分支；文件记录会进入图片路径读取。因此旧版不包含后来新增的文件拖放修复，不能用旧版面板验证最新源码。
- 退出旧进程后，现场旧安装进程随后又出现。保持本机安装版本和源码构建分开记录，不能仅凭应用名称认定正在操作修复版。

## 变更

- Debug 参数 `--test-clipboard` 直接打开固定的正式剪贴板面板；`ASKY_CLIPBOARD_TEST_QUERY` 可筛选测试卡片，避免历史刷新改变测试源位置。
- 此 Debug 模式日志只输出拖拽内容类型、数量、结束操作标记，不输出内容或路径。Release 不启用这些入口和日志。
- README 中英文记录正式面板验收方式和多实例限制；AGENTS.md 既有 README 命令发现机制保持有效，无模块边界变化。

## 已执行验证

- `xcodegen generate` 及 README Debug `xcodebuild` 通过。
- Packages/KulaCore 的 README `swift test` 通过。
- 正式 Debug 主应用（PID 31600，修复构建绝对路径）通过本机临时文件测试：原生卡片启动文件拖放，Chrome 接收操作为 copy。网页回读 Asky拖放测试.txt，text/plain，33 bytes，内容逐字节一致。
- 同一正式面板拖至真实 Orca Terminal input：结束操作为 copy；目标截图显示完整的测试文件路径进入 Codex 输入区。未提交；测试后通过 CUA Ctrl+U 清空输入，截图确认恢复空白提示。仅删除本次生成的 fixture 路径对应历史行，保留用户历史。该结论覆盖终端输入，不推断 Orca 聊天附件视图。
- 原生输入测试使用真实系统光标移动以及按下、拖动、松开，并从目标回读。第一次 Chrome 指定在副屏的坐标已无目标窗口，operation=0，未记为通过；确认 Chrome 当前位于主屏后重新选择外部区域，operation=1 并取得文件数据。

## 尚待验证

- 微信辅助功能树不能提供可操作的内部控件，自动搜索不能可靠选择文件传输助手。已请求用户将微信停在文件传输助手，避免误碰正在使用的群聊；未执行微信文件发送，尚未记录其接收通过。
- `/Applications/Asky.app` 仍是 0.0.14，没有本次源码修复。此记录不代表已更新安装版或发布新版本。
- 测试 fixture、过程日志、截图与辅助程序沿用 build/ 忽略规则，不提交用户界面截图或个人数据。
