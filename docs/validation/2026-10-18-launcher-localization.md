# 启动器多语言遗漏修复

## 范围与原因

- 标签页搜索底部按钮读取 `Launcher.strings`，此前只在 `Localizable.strings` 中存在翻译。补齐标签页、链接与 AI 搜索按钮的中英文键。
- 内置网站建议、网站命令结果及输入框图标的无障碍标签此前直接使用核心包的中文名称。现在在 App 展示层读取本地化资源；保留关键词、URL 与用户输入。
- 网站命令结果的格式和“仅打开网页”提示同步本地化。

## 验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，Swift Testing 合计 260 个测试、51 个 suite（13 个测试运行）。
- 四份修改后的 `.strings` 经 `plutil -lint` 校验通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-application-language-regression.py -AppleLanguages "(en)"`：通过。首次编译期间调整测试 fixture 导致输入文件变化检查失败，稳定文件后重跑通过。
- `build/ApplicationLanguageRegression.app/Contents/MacOS/ApplicationLanguageRegression -AppleLanguages "(zh-Hans)"`：复用上述编译的同一原生回归程序，通过。
- 两种语言均覆盖四个搜索入口及操作按钮、全部内置网站指令建议与查询结果；混合中文/英文用户输入保持原样。
- 已查看 `build/launcher-language-en.png` 和 `build/launcher-language-zh-Hans.png`：英文底部为 `Search Open Tabs`，结果为 `YouTube Search`；中文保持原文。既有语言偏好迁移、系统跟随重置、设置窗口标题回归亦通过。

## 文档与工作区

- README: unchanged；修正既有多语言功能的遗漏，使用与构建命令未变。
- AGENTS.md: unchanged；模块边界、开发命令与长期约定未变。
- 复用 `.gitignore` 的 `build/` 规则存放原生回归程序与截图。
- 保留任务开始时已有的未跟踪文件 `docs/validation/2026-10-18-icon-preview-app.md`。
