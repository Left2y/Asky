# 原生 Dialog / Alert 核对

补充：本记录只确认了使用 NSAlert，未正确区分独立 alert 与 sheet，不能作为参考图外观验收。后续修正与验证见 [原生 sheet](2026-10-17-native-alert-sheets.md)。

日期：2026-10-17。环境：macOS 27.0.1，本地 Debug 构建。

## 结果

- 全文检查 App 与 ToolService 的 `NSAlert`、`.alert`、`confirmationDialog` 和 `runModal` 调用：现有 alert 经 `AppDialog.make()` 创建，使用系统 `NSAlert`，没有自绘窗口表面或按钮布局。本次没有修改 Swift 代码。
- 在设计系统与中英文 README 中明确原生弹窗规范：外观由 AppKit 管理，不固定复刻参考图。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令运行通过（`BUILD SUCCEEDED`）。构建日志有 Xcode CoreDevice / Simulator 插件兼容提示，没有阻止 macOS 构建。
- 启动新构建 `Asky.app --test-confirmations`，通过 PID 72092 检查实际窗口：显示应用图标、标题、说明、操作详情、确认执行及不执行按钮。
- 点击操作详情后，读回展开状态与参数文本，窗口高度随内容增加；点击不执行后读回下一项“修改日程？”确认，未执行实际工具。随后关闭此次预览进程。
- Escape 检查因预览窗口未获得键盘焦点而被自动化拒绝，未记为通过。未覆盖深色外观、macOS 15 或全部七项预览。
- `git diff --check` 通过。未修改 Swift / AgentRuntime，因此未运行核心包或 Node 测试。

## 维护检查

README: updated，中英文同步说明原生 NSAlert。AGENTS.md: unchanged，现有 App 指令已链接设计系统，构建命令与模块边界不变。构建产物沿用现有 `build/` 忽略规则。
