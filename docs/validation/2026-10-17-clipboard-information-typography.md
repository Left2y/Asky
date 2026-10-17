# 剪贴板信息区字号

剪贴板列表式右侧预览下方的来源、类型、尺寸、大小与复制时间统一改用 14 pt 系统常规字重；仅调整信息区，不改变历史行字号与上下布局。

## 验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过布局切换、选中保留、搜索、固定及复制回归；检查 `build/clipboard-layout-list-image.png` 与文本预览截图，信息区无截断，保持底部对齐。截图沿用已有 `build/` 忽略规则。

留白反馈尚待明确是左侧历史列表还是右侧信息区，本次不调整布局。
