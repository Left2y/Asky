# 剪贴板列表点击与回车复制

日期：2026-10-17。

## 行为

- 列表点击记录时选中并复制，复用卡片的复制状态 toast。
- 列表搜索框中按回车复制当前选中内容，保持窗口打开；方向键继续切换选中项与预览。
- 无障碍默认操作同样选中并复制，并提供命名复制操作。复制失败沿用原有错误提示。
- 卡片回车原有粘贴流程、列表右键菜单与原生拖放不变。

## 验证

- `xcodegen generate`：通过。
- README 中 Debug `xcodebuild`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：已运行两次，均有 AgentHostTests 的 `RealRuntimeIntegrationTests.unreachableModelFailsAndProcessIsGone` 失败（缺少 `.running` 状态与运行 PID）；其余套件通过，未修改该运行时测试。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过，覆盖实际行鼠标点击、回车委托、剪贴板内容、选中项、窗口保持打开与 toast 子窗口可见性，以及原有布局／搜索／固定回归。首次运行在原有选中项断言处因窗口提前隐藏失败；将布局回归在显示前固定窗口后通过。
- 已查看 `build/clipboard-layout-list-copy.png` 和 `build/clipboard-layout-list-copy-toast.png`，确认选中记录预览与“已复制”提示。

回归使用临时数据库、真实窗口和实际行鼠标视图／搜索框委托，直接读取系统剪贴板与 toast 子窗口；不等价于物理鼠标或全局键盘验收。测试在显示窗口前固定窗口，避免桌面焦点变化提前关闭窗口并清空数据。

截图与测试程序沿用已忽略的 `build/`，没有添加忽略规则。
