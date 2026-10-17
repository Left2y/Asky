# MingCute 功能图标统一

日期：2026-10-17。

## 实现范围

- App 内功能图标统一由本地 MingCute 矢量模板渲染，覆盖启动器及筛选、剪贴板、对话/附件/Markdown、日程、提醒、权限与设置按钮。
- 65 个独立图形与 17 个现有功能/侧栏资产别名随 App 打包。大小从原图标字号显式传入，固定、停止、星标等状态使用填充图形。
- Asky 品牌图、实际应用/网站标识、用户选择的插件图与内容缩略图保持其身份或内容用途。
- 自动审批使用用户提供的 `hand_line`，`App/Artwork/approval-hand.svg` 保留原始输入；打包时将不透明 `#09244BFF` 规范为兼容资产目录的 `#09244B`，路径与几何不变；按钮与审批菜单共享映射。初次选用的 `safe_shield` 图形在 24×24 画布中只占很小区域，真实窗口中呈现为小点，已按用户指定替换。
- 聊天消息与代码块复制采用用户提供的 `copy_2_line`，原始 SVG 保存在 `App/Artwork/copy.svg`，同样规范不透明颜色后打包。
- 固定上游版本及映射位于 `scripts/mingcute-icons.json`；导入脚本已实际执行，源图形与 Apache-2.0 许可保留在项目和 App 资源中。

## 已运行的检查

| 检查 | 结果 |
| --- | --- |
| `xcodegen generate` | 通过 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build` | 通过，最终 hand_line 资产已构建 |
| KulaCore：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | 258 个 Swift Testing 测试通过 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py` | 原生设置深浅色截图、授权窗口生命周期与拖拽卡片恢复通过 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --accessories` | 深浅色筛选隔离、输入位置、菜单画布、固定/失焦/Escape 通过 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py` | 回复、澄清持久化、取消、用时、附件顺序/历史恢复、新对话回归通过 |
| App/Sources 图标扫描 | 无 `Image(systemName:)`、`NSImage(systemSymbolName:)` 或 SF Symbols Label 渲染；字面量图标键全部有映射 |
| 资产清单核对 | 清单中的独立图形与别名文件均存在，并标记为矢量模板 |
| `git diff --check` | 通过 |

直接检查了新编译 AgentReplyRegression 的实际对话窗口：自动审批按钮与菜单手掌图标、消息复制双方框图标正常显示。最终资源中提供的八位颜色值在首次编译中导致图形不显示，去掉不透明 `FF` 后已重建并再次目视核对。代码块与消息复制共用同一 ChatCopy 资源。

直接检查了本次设置回归生成的浅色通用、深色权限截图，以及本次新编译的 LauncherWindowRegression 启动器窗口。截图与测试程序位于已忽略的 `build/` 中，不提交。

首次裸 `swift test` 使用 Command Line Tools，因缺少 `Testing` 模块失败；使用完整 Xcode 后通过。Xcode 输出本机 CoreDevice/CoreSimulator 版本警告，macOS App 构建仍成功。原生回归编译还有既有的 Swift 捕获与 AppKit API 警告。
