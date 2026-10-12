# 操作确认使用系统弹窗

日期：2026-10-12。

用户要求采用请求日历权限时的系统 dialog 布局。`ConfirmationCenter` 改用 AppKit `NSAlert`，由系统提供应用图标、标题、说明、按钮、材质和焦点行为，不再维护自定义标题栏、玻璃卡片或固定尺寸。保留来源、工具、目标、变更、备注与待确认数量；请求仍逐项确认，只有首按钮返回 approved，取消、Escape 和中止均返回 rejected。退出时仍通过 rejectAll 结束所有等待中的请求。

## 已执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：230 项 Swift Testing 测试通过。
- 独立原生探针直接编译最终 `ConfirmationCenter.swift` 与构建出的 Contracts，展示截图中的模拟删除请求；没有调用 ToolService 或 EventKit，没有删除真实日程。
- Orca computer-use 捕获并人工检查浅色与深色 NSAlert：260 × 321pt，图标、说明、两个系统按钮完整显示。探针使用默认图标，正式应用由系统读取 Asky 的应用图标。
- 浅色探针 Escape 后读回 `decision=rejected`；深色探针点击确认后读回 `decision=approved`。工具的动作后截图因窗口随探针退出而失败，结果以探针写出的返回值及进程退出为依据。
- 本地截图保存于 `build/validation/confirmation-system-dialog/light.png` 与 `dark.png`，由现有 build 忽略规则排除。

## 验证边界

本次验证了最终组件的系统窗口及模拟确认结果；未再次发起真实日程删除，也未验证真实系统权限申请。多请求排队、退出中止沿用现有确认语义，未做交互式多请求回归。

README 与 AGENTS.md 检查后保持不变：本次仅更换确认界面的系统呈现，不改变操作方式、开发命令或架构边界。
