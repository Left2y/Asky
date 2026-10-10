# 输入框粘贴快捷键修复与现场验证

日期：2026-10-10。前次实现记录：[附件实现](2026-10-10-composer-attachments.md)。本记录补充实际窗口验证，不以核心测试代替 UI 验收。

## 问题与修复

- 在 PID 69292 的真实 KulaHere 窗口中，将 PNG 放入剪贴板后按 Cmd V，附件数量及界面未变化；当时消息输入框已聚焦。
- App 由 NSApplication 启动，未安装标准 Edit 菜单。仅重写 NSTextView.paste 不能保证 Cmd V 路由；纯文本编辑器的默认粘贴验证也不覆盖图片附件。
- ComposerTextView 显式处理 Cmd V 的 key-equivalent 和 keyDown fallback，并允许粘贴动作验证；普通文字仍交给 NSTextView.paste，启用原生 undo。
- 文件选择器允许 data / image / text 类型；失败返回值显示错误，不再静默忽略。本轮没有复现所有文件选择失败场景，不能断言它们均有相同原因。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：119 tests / 24 suites 通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 正常退出旧 App，打开 Debug 构建；进程 PID 更新为 77225。使用 computer-use 技能通过 Orca 在真实 720 × 640 pt 窗口中验证。
- PNG 图片 Cmd V：从空输入框变为一个方形图片卡片；截图确认 1:1 裁剪。
- 文件选择：从附件菜单打开系统文件选择器，选择项目 README.md，点击 Open 后显示 README.md / 16 KB，与图片横向排列。
- Finder 文件引用 Cmd V：剪贴板以 NSURL 写入 README.md 后，输入框出现文件卡片。
- 悬停文件卡片：实际截图显示右上角 x 删除按钮；点击后文件卡片消失。图片删除也已通过前后 UI 回读确认。
- 普通文字 Cmd V：输入框回读到“粘贴输入测试”，清空测试文字后未发送任何消息。
- 恢复测试前保存的剪贴板内容。最后一个测试 README 附件留在草稿中，因桌面焦点检测间歇性返回 window_not_focused，最后清理动作未获确认；没有将附件发送给模型。
- `git diff --check`：通过。

现场截图（本地临时产物，不纳入 Git）：
- 图片粘贴：`/var/folders/n5/q0bmv3hd3rv1q8_rkkmbp59w0000gn/T/orca-computer-use/7d7f5545-004e-4484-84fb-6444c61cd57f-screenshot.png`
- 文件与图片横排、悬停删除：`/var/folders/n5/q0bmv3hd3rv1q8_rkkmbp59w0000gn/T/orca-computer-use/e12c2c29-3079-485d-9cb8-4e5ec67a782f-screenshot.png`

## 验证边界

本轮未执行真实模型图像回答、深色主题、减少透明度、输入法组字、多附件滚动及拖入回归。未修改或发送已有对话。README: unchanged，使用方式没有变化。AGENTS.md: unchanged，工具与构建规则继续有效。构建产物沿用已有忽略规则，原有 acceptance-v1.md 不纳入任务提交。
