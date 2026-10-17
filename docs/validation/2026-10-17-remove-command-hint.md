# 删除指令页底部提示

- 删除“输入指令后按空格，再输入内容。内置指令固定，无需添加或修改。”提示行；其自动生成的分隔线随之消失。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，37 个测试。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py`：通过；查看 `build/settings-light-keywords.png`，确认列表结束后没有提示行。
- README 与 AGENTS.md 无需更新：仅删除界面辅助文字，使用流程、构建命令及架构规则不变。
- 构建与回归产物复用已有 `build/` 忽略规则。
