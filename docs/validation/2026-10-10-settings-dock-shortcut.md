# 设置 Dock 与面板快捷键

- 设置打开时切换为 regular 应用（Dock 可见）；关闭设置恢复 accessory 菜单栏常驻模式。设置可见时重新打开 App 回到设置。
- 搜索和剪贴板非激活面板在字段编辑器处理前接收 ⌘,，通过现有设置入口打开窗口，同时收起两种面板及剪贴板预览。

## 已运行验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：145 项通过。首次未指定完整 Xcode 时因缺少 Testing 模块失败；切换工具链后通过。
- `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令：通过。
- 重启实际 Debug App，原生控制读取搜索输入框后按 ⌘,，实际设置窗口出现。
- 使用 NSRunningApplication 读取实际进程 activationPolicy：设置打开时为 0（regular），关闭后为 1（accessory）。Dock 的直接 AX 读取超时，未取得 Dock 截图。
- 剪贴板完整回归执行到预览定位时失败：`preview is centered under the card`。此前新增的两种面板 ⌘, 事件路由断言已通过；该预览定位问题未纳入本次修改。
- 单独运行 `python3 App/Tests/run-clipboard-regression.py --settings-shortcut`，验证实际 LauncherPanel / ClipboardPanel 的事件处理及设置回调，并检查额外 Shift 修饰键不会触发设置。

## 文档与范围

README 同步中英文行为和回归命令。AGENTS.md 无需更改：现有构建、测试命令和模块边界未改变。未打包 Release 或安装应用；运行仓库内 Debug 产品。生成的构建和截图沿用现有 `build/` 忽略规则。
