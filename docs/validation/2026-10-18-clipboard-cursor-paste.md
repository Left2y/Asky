# 剪贴板输入焦点与粘贴操作

日期：2026-10-18。

## 行为

- 打开历史面板前，由 ToolService 捕获原应用及其辅助功能输入元素。
- 有已识别输入焦点：列表底栏显示“粘贴到光标位置 ↩”；“复制到剪贴板 ⌘↩”位于更多菜单。
- 无已识别输入焦点：列表底栏显示“复制到剪贴板 ⌘↩”；普通回车不执行，更多菜单不重复复制操作。
- 卡片和列表的键盘行为一致；⌘回车始终只复制、保留面板，在更多菜单内也不会误执行当前高亮的固定或删除动作。
- 自动粘贴先复制，再隐藏面板并恢复目标；发送前核对原应用、输入元素和剪贴板 changeCount。目标失效时提示手动粘贴，不猜测输入位置。
- 焦点检测需要辅助功能权限；未授权、无输入或无法识别的自定义控件显示复制操作。检测结果属于本次唤起前的输入位置，不跟随面板内的搜索框焦点。

## 实际执行

| 检查 | 结果 |
| --- | --- |
| `xcodegen generate` | 通过 |
| README 的 Debug `xcodebuild` 命令 | 通过 |
| `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | 最终全量通过 |
| `swift test --filter ClipboardAccessTests`（同目录、同 DEVELOPER_DIR） | 9 项通过 |
| `python3 App/Tests/check-localization.py` | 140 个 Swift 源文件检查通过 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --paste-target` | 通过 |
| `build/ClipboardRegression.app/Contents/MacOS/ClipboardRegression --layouts` | 使用上述命令新编译的同一测试包执行，通过 |
| `git diff --check` | 通过 |

跨进程用例启动独立 AppKit 接收窗口，在 `LeftRight` 的第 4 个字符后放置光标，经真实剪贴板与合成 ⌘V 读回 `LeftPASTERight`。同时检查菜单复制不插入、更多菜单高亮删除时 ⌘回车仍只复制、输入失焦后切换为复制、普通回车无操作，以及剪贴板在派发前被改写时拒绝粘贴。

已查看原生视图渲染产物 `build/clipboard-focused-footer.png` 和 `build/clipboard-layout-list.png`，分别确认有焦点及无焦点的底栏内容。构建、临时接收应用、截图沿用现有 `build/` 忽略规则。

首次全量核心检查因本机缺少 `@earendil-works/pi-coding-agent` 而在真实 AgentRuntime 集成用例失败；执行 `cd AgentRuntime && npm ci && npm run build` 补齐本地依赖和构建产物后，重新运行全量检查通过。依赖与产物沿用现有 `node_modules/`、`dist/` 忽略规则，未修改 Runtime 源码或锁文件。

## 边界

本次真实插入验收覆盖独立 AppKit 文本输入。不同应用、自定义编辑器、只读控件对辅助功能和粘贴的支持不同；无法确认输入位置时保守显示复制。事件已派发不等于目标应用已接受所有内容，不承诺所有第三方输入控件均支持自动粘贴。
