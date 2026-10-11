# 剪贴板窗口外层阴影

日期：2026-10-11。

## 修复

剪贴板面板保留 `hasShadow = false`，使用与搜索窗口相同的外层 SwiftUI 阴影：半径 40 pt、X 0 / Y 12 pt、浅色黑色 24% / 深色黑色 40%。透明画布四周预留 132 pt，阴影在玻璃层外绘制并挖空面板内部，避免被圆角或窗口边界裁切、污染玻璃背景。

可见面板维持原有尺寸与位置。点击外部关闭和完整预览定位使用扣除阴影留白后的面板边缘；回归检查相应区分窗口画布与可见面板。`--preview` 测试窗口在显示前固定，便于跨应用检查。

## 已执行验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk python3 App/Tests/run-clipboard-regression.py`：完整通过，覆盖搜索、固定、删除、悬停延迟、预览间距与窗口释放。
- 独立原生测试窗口 `--preview`：在第二块屏幕截图检查了浅色玻璃与外层阴影，阴影没有被窗口边缘裁切。截图为本地忽略产物 `build/clipboard-shadow-desktop.png`。深色生成截图来自完整回归；本轮没有单独做深色实窗验收。

默认回归命令首轮遇到编译 SDK 不一致：模块使用 macOS 27.0 SDK，而脚本编译选到 26.5；指定上述 SDKROOT 后通过。

## 文档与提交检查

- README: unchanged，修复既有视觉效果，不改变使用方式或开发命令。
- AGENTS.md: unchanged，没有引入新的持久指令或模块边界。
- 原有工作区包含未提交的语言配置与预览几何修改；本次补丁对索引的只读检查在预览几何和回归检查处冲突，未混合提交这些已有修改。
- 构建、工程和截图继续由现有 `.gitignore` 覆盖，没有新增忽略规则。
