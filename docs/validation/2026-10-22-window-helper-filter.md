# 窗口搜索：过滤 Chrome 辅助表面

日期：2026-10-22。

## 原因与修改

现场只读 AX 诊断中，Chrome 暴露三个 AXWindow：两个标题为空、子角色为 AXUnknown、高度为 41 / 81 的辅助表面，以及一个有标题的 AXStandardWindow 网页窗口。两个辅助表面均没有 AXCloseButton，原代码却将其以应用名显示为两个 Google Chrome 结果。现场辅助功能权限已开启，原通用失败提示不能据此判断为权限故障。

ToolService 现在保留标准窗口、对话框、有标题或有关闭按钮的窗口，排除缺少这些特征的辅助表面；标准无标题文档窗口仍保留。窗口操作失败时区分实际权限缺失和目标已关闭／不可操作，并使旧快照失效。中英文提示同步。

## 已执行

- `xcodegen generate`：通过。
- `(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)`：通过；包含新增辅助表面过滤与无标题标准窗口保留用例。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/WindowSearchDerivedData build`：通过。
- 使用新构建的 ToolService，通过临时只读诊断程序调用 `launcherWindows()`：Chrome 返回 1 个有标题的实际网页窗口，两个辅助表面均被排除。
- `ASKY_DERIVED_DATA=build/WindowSearchDerivedData DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --window-search-live`：通过；同标题窗口保持独立、精确聚焦、最小化恢复、精确关闭、旧目标拒绝与正常退出测试应用均通过。仅关闭和退出测试夹具，未关闭用户 Chrome 窗口。
- 两个语言的 `Localizable.strings` 经 `plutil -lint` 检查通过。

## 验证边界

已验证真实 Chrome 的新列表数据以及独立原生窗口夹具操作。未替换 `/Applications/Asky.app`，未验收已安装版本的新界面或模拟撤销系统权限。编译中的已有警告未作为功能通过依据。

README 与 AGENTS.md 检查后保持不变：此次为已有窗口搜索能力的缺陷修复，无新使用方式、构建命令或模块边界。
