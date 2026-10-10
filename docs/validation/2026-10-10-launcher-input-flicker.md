# 快捷搜索输入闪烁与位置抖动修复

日期：2026-10-10。

## 原因与改动

- 原生搜索框在每次 SwiftUI 更新时重新设置字体、文字颜色和占位符，即使这些值没有变化。AppKit 会把这些设置传递给正在编辑的 field editor。改为仅在属性实际变化时写入，保留实时编辑器和选区。
- 搜索结果变化先触发 SwiftUI 布局，再异步调整 NSPanel 高度。原先固定高度的搜索内容在旧窗口内默认居中，形成短暂的纵向位移。现在在内容高度测量之外增加顶部对齐的容器，让输入位置在窗口调整前后保持顶部锚定。
- 不改变关键词消耗、空正文退格、方向键、提交或搜索取消逻辑。

## 已运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression` 与 `build/launcher-input-regression`：通过。新增连续 40 次更新检查，确认不重复写入样式、不替换活动编辑器、不移动正文中的选区；实际样式变化仍能应用。原有关键词与退格检查继续通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：128 tests / 27 suites 通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 已退出原有 Debug 进程并打开新构建。

## 验证边界

computer-use 按 PID 唤起快捷搜索后取得一次面板截图，但没有可用的焦点或辅助功能树；随后读取窗口返回 `window_not_found`，再次列举窗口为空。未完成真实连续键入、中文输入法、主题切换或逐帧位置测量，不把自动化输入调用或单次截图记为视觉验收通过。

README 与 AGENTS.md 维护检查：本次仅修正既有输入行为，没有新增命令、产品使用方式或模块边界，保持不变。构建、日志与回归二进制均由现有 `build/` 规则忽略。原先未跟踪的 `docs/validation/acceptance-v1.md` 不属于本次改动。

执行期间 `LauncherView.swift` 出现了外部的顶部位置与底部留白改动。构建验证的是当时工作区；提交仅包含本次顶部对齐修复，外部改动保留为未暂存内容。
