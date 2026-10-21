# 移除快捷键设置分组脚注验证

- 删除「快捷键」设置页四个分组下方的说明小字（文件与应用、启动器、剪贴板历史、AI 对话），分组本身与条目保持不变。
- 同步移除 `en.lproj` 与 `zh-Hans.lproj` 中仅被这些脚注使用的四条本地化键，`check-localization.py` 通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData -skipPackageUpdates build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `python3 App/Tests/check-localization.py`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --hotkeys-only`：通过。
- 已查看 `build/settings-light-hotkey.png`、`build/settings-light-hotkey-scrolled.png`，分组之间不再显示脚注文字。
- `git diff --check`：通过。
- README: unchanged；使用方式、命令与依赖未变。
- AGENTS.md: unchanged；未改变架构边界或开发流程。
