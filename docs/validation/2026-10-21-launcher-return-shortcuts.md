# 启动器回车组合键调整

- 默认在访达中显示改为 `⌘ Return`，询问 AI 改为 `⌃ Return`；设置页与动作提示共用同一配置。
- 解码旧偏好时迁移旧默认组合，保留自定义组合；迁移经现有冲突检测，目标组合已被占用时不覆盖。
- 已通过：`xcodegen generate`；README 的 Debug `xcodebuild` 命令；`cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（43 tests）；`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --local-shortcuts`。
- 原生回归覆盖旧配置迁移、保存重载、自定义保留、Return/数字键盘 Enter 的修饰键区分、原生输入框访达回调及启动器 AI 回调。实际 Finder 窗口与远端 AI 请求未执行。
- 检查回归生成的浅色设置截图 `build/shortcut-edit-light.png`，访达显示为 `⌘ ↵`，询问 AI 为 `⌃ ↵`。截图及编译产物由现有 `build/` 忽略规则排除。
- README 中英文及 PRD 已同步；AGENTS.md 无需变更，现有架构与验证命令适用。
