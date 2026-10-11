# Background 透明度调整

按用户要求，`Colors/background` 的 Light / Dark 分别从 `Palette/white70` / `Palette/black70` 改为 `Palette/white60` / `Palette/black60`，alpha 均为 0.6。保留现有 white / black 基础色和其他语义 token；设计系统文档同步当前映射。

实际执行：

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
- `git diff --check`：通过。

本次未进行实际窗口视觉检查，未打包或安装。构建输出继续使用现有 `.gitignore` 规则。

README: unchanged — 仅调整背景 token 透明度，不影响使用方法与开发命令。

AGENTS.md: unchanged — 不涉及持久指令、模块边界或验证流程变更。
