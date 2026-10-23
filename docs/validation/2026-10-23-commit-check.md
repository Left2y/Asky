# 提交前检查

日期：2026-10-23。

针对当前插件设置展示列表、设置分类标签及窗口全屏功能撤销的合并工作区，实际执行：

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，13 个测试运行合计 307 项。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData-commit-check build`：BUILD SUCCEEDED。
- `python3 App/Tests/check-localization.py`：通过，157 个 Swift 源码文件。
- `git diff --check`：通过。

本次未重跑原生 UI 回归或物理键盘交互；既有 UI 验证结果与限制保留在各专题记录中。构建目录复用现有 `build/` 忽略规则。
