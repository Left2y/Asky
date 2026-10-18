# 剪贴板操作栏与卡片更多菜单

## 范围

- 列表底部复用搜索的玻璃按钮、快捷键样式：左侧“复制到剪贴板 ↩”，右侧“更多 ⌘K”。
- 更多菜单提供 Pin / Unpin、删除记录，支持方向键、回车、Esc；搜索、切换记录、布局和关闭窗口时收起菜单。
- 列表单击只选中，双击或回车复制，移除行右键菜单。
- 卡片保持单击复制、拖放和现有右键菜单；悬停时右上角显示设置同款 `SettingsMoreMenu` dots 按钮，点击打开复制、固定／取消固定、删除菜单。

## 已执行检查

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过。覆盖真实渲染行鼠标回调、单击无剪贴板写入、双击复制、原生输入框回车复制、⌘K 打开／关闭、Pin / Unpin 保持目标记录、方向键与 Esc、删除与空结果、布局切换、卡片单击复制，以及提示条生命周期。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --card-actions`：通过。通过真实鼠标移动和点击验证悬停 dots 及打开原生菜单，点击 dots 不写剪贴板；已检查 `build/clipboard-card-hover-actions.png` 和 `build/clipboard-card-actions-native.png`，确认菜单包含复制、固定记录、删除。
- 最新回归可执行文件再次执行 `--layouts`：通过。
- `python3 App/Tests/check-localization.py`：通过，139 个 Swift 源文件的语言键值、格式参数和静态本地化检查。
- `(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)`：未全过。`PluginTests.nativeWorkerRoundTripAndPolicy` 因缺少 `AgentRuntime/dist/src/plugin-runner.js` 出现四个断言失败；包括 `ClipboardAccessTests` 在内的其他测试通过。本次未改核心包或 AgentRuntime。

## 视觉检查

- 已检查 `build/clipboard-layout-actions-footer.png` 与 `build/clipboard-layout-actions-menu.png`：操作栏无内容遮挡，菜单为独立圆角表面，包含 Pin 与删除记录。
- 本地构建、截图和回归应用使用现有 `.gitignore` 的 `build/` 规则，不提交二进制或截图。

README 中英文已同步交互变化；AGENTS.md 无架构、模块边界或开发命令变化，保持不变。

## 复制按钮图标调整

- “复制到剪贴板”底栏按钮复用 `ChatCopy` 模板资产（`copy_2_line`，源文件 `App/Artwork/copy.svg`），保持 14 pt 图形大小。
- 已重新执行 `xcodegen generate` 和 README 的 Debug 构建命令，均通过。
- 已重新执行 KulaCore `swift test`：仍仅 `nativeWorkerRoundTripAndPolicy` 因缺少 plugin-runner 产物出现四个断言失败。
- README 无使用方式变化，保持不变；AGENTS.md 无持续开发规则变化，保持不变。
- 图标调整后重新运行 `run-clipboard-regression.py --layouts`：通过；已检查新生成的 `build/clipboard-layout-actions-footer.png`，底栏显示 `copy_2_line`。截图仍由既有 `build/` 规则忽略。
