# 剪贴板菜单复制与粘贴后保留窗口

日期：2026-10-18。

## 行为

- 列表“更多”始终提供“复制到剪贴板 ⌘↩”与“删除记录”。复制只更新系统剪贴板，保留窗口。
- 原应用存在可用输入目标时，列表与卡片菜单增加“粘贴并保持窗口开启”。操作先复制内容，再通过 ToolService 粘贴到原应用光标位置；保留窗口位置、搜索词、选中项及原有窗口固定状态。
- 为释放非激活面板占用的键盘焦点，派发粘贴时短暂移出面板，待事件投递后恢复显示，不重新创建界面、不抢回输入焦点。菜单关闭，原应用可继续输入。
- 普通回车继续使用原有粘贴并关闭行为，⌘回车继续仅复制。无可用输入目标时不显示自动粘贴菜单项；目标失效时保留复制内容并提示手动粘贴。

## 实际验证

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `python3 App/Tests/check-localization.py`：142 个 Swift 源文件检查通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --paste-target`：通过。独立 AppKit 接收窗口从 `LeftRight` 变为 `LeftPASTERight`；未固定窗口保持可见，窗口位置、搜索词、选中项及固定状态保持，输入焦点留给接收窗口。随后普通回车插入第二次内容并关闭面板；同时覆盖菜单复制不插入、无输入目标与剪贴板竞争保护。
- `build/ClipboardRegression.app/Contents/MacOS/ClipboardRegression --layouts`：通过。覆盖两项菜单的键盘选择、删除、Esc、窗口与搜索焦点保持。
- `ASKY_CLIPBOARD_RECEIVER="$PWD/build/ClipboardPasteReceiver.app/Contents/MacOS/ClipboardRegression" build/ClipboardRegression.app/Contents/MacOS/ClipboardRegression --drag-paste-target --list-drag --pinned-drag`：通过。覆盖列表固定窗口的拖放补粘贴、取消、非输入区域与避免重复插入。

原生截图位于 `build/clipboard-keep-open-menu.png`；视图渲染与布局产物位于 `build/clipboard-focused-footer.png` 与 `build/clipboard-layout-actions-menu-{light,dark}.png`。已查看三项菜单原生截图及浅色、深色布局截图，确认菜单文字完整、快捷键与图标排列正常。构建、测试应用、日志、基线副本与截图均沿用现有 `build/` 忽略规则。

首次回归编译因编译期间继续编辑源文件被编译器中止；源文件稳定后重新编译并执行通过。补取原生截图的编译又遇到并行构建改写共享 `Search.o`，最终复制 Debug 产品到 `build/task-clipboard-keep-open/ProductsSnapshot`，仅在临时运行器内替换 `products` 路径，使用稳定快照编译；未修改项目回归脚本。构建日志包含本机 Xcode/CoreDevice 插件兼容性警告，未阻断 macOS 构建。

README 中英文已同步；AGENTS.md 无需修改，未引入新命令、模块或系统访问边界。工作区原先已有菜单重构、移除记录固定和筛选等未提交改动，本次修改与相同枚举、菜单和回归用例重叠并依赖这些改动，未混合提交，原索引保持不变。

## 验收边界

真实插入验收覆盖独立 AppKit 文本输入；其他应用自定义输入控件仍受原有辅助功能权限与应用粘贴能力限制。
