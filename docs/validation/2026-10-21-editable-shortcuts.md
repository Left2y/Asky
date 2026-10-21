# 快捷键设置可编辑验证

日期：2026-10-21。

## 改动

快捷键设置中原先静态展示的按键改为原生录制按钮，支持保存和恢复默认。29 个窗口内动作使用稳定 ID 保存，保留已有访达显示、复制路径与三个全局快捷键配置；旧设置缺少新字段时使用原默认值。方向键分开录制。同一窗口中的重复组合及全局入口冲突会被拒绝，不同窗口可使用相同组合。“打开设置”在启动器、剪贴板和 AI 中共享配置。

启动器、剪贴板和 AI 编辑器按配置处理按键；底栏及更多菜单显示当前快捷键。输入法组字时保留编辑器处理，空输入退格导航与普通文本删除保持原条件。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：最终构建通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：298 项 Swift Testing 测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --local-shortcuts`：通过。覆盖全部 29 项默认值迁移、修改和重新加载；同窗口冲突拒绝、跨窗口复用；实际 SettingsWindow 中点击“复制文件”的 NSButton 录制并保存、拒绝已占用回车；恢复默认；启动器 AI、剪贴板复制和 AI ComposerTextEditor 改键后触发，新旧按键行为断言。
- `python3 App/Tests/check-localization.py`：通过，152 个 Swift 源文件，语言键、格式参数和静态本地化检查通过。
- `git diff --check`：通过。

原生回归生成 `build/shortcut-edit-light.png` 和 `build/shortcut-edit-dark.png`，已查看两张截图：文件与应用及启动器项目显示录制和恢复默认按钮，修改后的组合正确显示。截图来自实际构建的原生窗口，使用独立临时数据目录，不修改用户设置。构建、回归可执行文件及截图沿用现有 `build/` 忽略规则。

## 验证边界

原生回归通过 AppKit 按键事件和录制按钮验证，不等于真实键盘在所有输入法、第三方应用焦点状态和系统保留组合下的端到端验收。未发布安装包，也未替换当前运行的用户应用。AGENTS.md 无新的长期规则、命令边界或子项目变化；README 中英文同步更新可编辑行为与回归命令。
