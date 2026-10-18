# 剪贴板列表底部悬浮操作

日期：2026-10-18。

## 修复

剪贴板列表的操作栏原先是纵向布局中的独立一行，导致列表和中间分隔线在按钮上方突然截断。现在将操作按钮叠放在列表底部，复用搜索结果的 alpha 渐隐参数；列表与分隔线自然消退，不增加底板。历史列表末尾增加可滚动留白，详情区域保留原有阅读空间，窗口尺寸与按钮位置不变。

## 实际验证

- `xcodegen generate` 和 README 的 Debug `xcodebuild`：通过，日志 `build/clipboard-floating-actions-build.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：267 项通过，日志 `build/clipboard-floating-actions-core-tests.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --floating-actions`：通过。使用临时数据库增加 24 条历史，运行真实 `ClipboardController`，分别捕获浅色、深色模式的列表顶部和末条选择。
- 已查看 `build/clipboard-floating-{light,dark}-{top,last}.png` 四张原生窗口截图：底部行和中线渐隐，按钮悬浮；键盘移动到末条后，选中行完整显示在按钮上方。
- 使用同次编译的 `build/ClipboardRegression.app/Contents/MacOS/ClipboardRegression --layouts`：通过，覆盖布局切换、持久化、旧配置默认值、选择、筛选、固定和复制；日志 `build/clipboard-floating-actions-layouts.log`。

构建、截图和回归应用均由现有 `build/` 忽略规则覆盖。此次未重新验收跨应用粘贴、拖放或旧版 macOS。
