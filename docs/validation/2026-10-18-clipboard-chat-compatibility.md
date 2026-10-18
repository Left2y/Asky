# 剪贴板聊天应用兼容性修正

日期：2026-10-18。状态：飞书真实文本插入通过；微信真实插入未验收通过。

## 原因与修正

此前仅用独立 AppKit 文本框验证，不能证明微信或飞书可用。对照 Tinycast 的 `Paster.swift`（提交 `f2df74cd7d1766f6fb444b8b9eb0eea626720d8d`）：普通粘贴恢复原应用后，通过 `.cghidEventTap` 发送 ⌘V；其向 PID 发送的分支用于保持面板打开的另一种交互，普通粘贴不依赖辅助功能输入元素的身份相等。

Asky 此前把“辅助功能未返回可识别输入框”当作“没有输入焦点”，还在隐藏面板后强制比较辅助功能元素是否相同，最后使用 PID 事件派发，兼容条件比 Tinycast 更严格。

本次变更：

- 焦点采用 `input / nonInput / unknown` 三种状态；明确非输入控件保留底栏复制，信息不足的自定义控件保留回车粘贴。
- 实际观察到微信焦点元素为 `AXButton`，可读 `AXSelectedTextRange`，但 `AXSelectedText`、`AXValue` 不可写。此类文本选区不能证明可编辑，也不能证明没有输入框，按 `unknown` 处理，不再直接拦截。
- 不再要求恢复前后辅助功能元素身份相同；恢复原应用后再次排除明确非输入焦点。
- 普通粘贴改为系统 HID ⌘V；继续核对目标应用、取消状态和剪贴板 changeCount，避免向已经切换的应用或用已改写内容派发。
- 补充自定义文本角色、未知焦点、普通按钮、禁用输入框和原生/Chromium 文本角色的回归测试。

以上取代[前次验证](2026-10-18-clipboard-cursor-paste.md)中的元素身份比较和“无法识别即复制”策略。

## 已执行检查

- `xcodegen generate`：通过。
- README 的 Debug 构建命令：通过。另一任务同时更新常规 DerivedData 后，改用 `-derivedDataPath build/PasteCompatDerivedData` 隔离构建，最终构建通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：最终全量通过，包含新增 4 项焦点分类测试。
- `python3 App/Tests/check-localization.py`：通过，140 个 Swift 源文件。
- 原生跨进程回归 `--paste-target`：通过，包含光标插入、更多菜单复制、明确非输入焦点、剪贴板改写防护；使用独立目录的最终产物和源文件快照复验亦通过。
- 飞书真实应用：使用实际 `ClipboardController` 和 ToolService，在原本为空的聊天输入框插入 `AskyPasteProbe`；通过辅助功能回读 `文本输入区 AskyPasteProbe` 确认插入。随后选中并移除此测试文本，回读恢复占位内容，全程没有向飞书发送 Return 或消息。

## 微信未通过部分

微信在测试过程中无法稳定恢复主窗口；Orca 返回 `window_not_found`，窗口列表为空，另一自动化接口给出空白截图。尝试键盘搜索及复制回读，结果未匹配测试文本，不能记为成功。已请求用户打开微信主窗口并定位空白输入框后继续验收。

因此，本记录只确认微信焦点分类不再按原有规则拦截，以及粘贴事件路径已调整；不声称微信真实输入、图片或文件已经通过。飞书目前仅确认真实文本插入，图片和文件不在本次通过范围内。

构建、源文件快照和临时应用使用现有 `build/` 忽略规则；并发任务的界面和 README 修改不属于本次提交。
