# 默认快捷键调整验证

- 搜索启动器保持 Option + Space（⌥ Space）。
- 剪贴板默认改为 Control + Shift + C（⌃⇧ C）。
- AI 空白新对话默认改为 Control + Shift + /（⌃⇧ /），仍使用斜杠物理键码。
- 新建配置、旧配置缺少的字段及设置中的“恢复默认”使用新值；已保存的快捷键保持不变。
- README 中英文与使用教程已同步。

## 实际运行的检查

- 默认配置检查：通过，确认搜索键码及修饰键保持不变，剪贴板与 AI 使用要求的键码、Control + Shift 及显示标签。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-settings-regression.py`：通过，包含旧配置字段补全、自定义 AI 快捷键保存和重新加载检查。
- `git diff --check`：通过。

本次未在实际 Asky 窗口中验证三个全局快捷键的触发或系统占用情况；构建结果位于 `build/DerivedData/Build/Products/Debug/Asky.app`。

## 文档维护

- README: updated，同步两种语言的默认快捷键。
- AGENTS.md: unchanged，本次不改变架构边界或开发命令。
- 构建日志、回归二进制及文档检查产物由现有 `build/` 忽略规则覆盖。
