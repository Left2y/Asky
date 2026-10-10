# 搜索菜单六行高度限制

日期：2026-10-10。

## 改动

- 搜索列表最大高度为 6 × 50 = 300 pt。分类标题与底部内边距包含在此预算内，避免滚动越过标题后同时显示超过六行。
- 少量结果按内容收缩；屏幕可用空间不足时仍使用更小的屏幕高度限制。
- 全部结果保留在 ScrollView 中，鼠标滚动与键盘选择后的自动滚动保持原有行为。

## 已运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：128 tests / 27 suites 通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：最终代码 BUILD SUCCEEDED。
- `git diff --check`：通过。

## 验证边界

未运行原生窗口 UI 自动化或重启正在运行的 App；构建与测试结果不代表真实窗口滚动、明暗主题或多屏验收。
