# 关于作者设置页验证

新增“设置 › 关于作者”独立侧栏页面，展示 Niall Young 与用户提供的邮箱、GitHub 主页和 X。邮箱使用 `mailto:`，网页使用 HTTPS，链接打开统一经 ToolService；提供打开失败提示。中文与英文资源及 README 用法同步。

## 已执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-settings-regression.py`：通过；包含所有侧栏页面的浅色、深色快照及既有窗口、授权生命周期检查。
- 打开新构建的 SettingsRegression 原生窗口，通过 Orca 点击“关于作者”，窗口标题与选中项正确；实际屏幕截图中三个地址完整可见，分组样式与现有设置一致。检查浅色、深色页面快照。
- 点击 GitHub 链接后，默认浏览器地址栏为 `github.com/Niall-Young`；点击 X 链接后，默认浏览器地址栏为 `x.com/NiallxYoung`。
- 两份 `Localizable.strings` 的 `plutil -lint`、README 本地链接/锚点/代码围栏与新增用法双语检查、`git diff --check`：通过。

## 验证边界

- 邮箱地址及 `mailto:niallyoung2002@gmail.com` 已核对，未实际打开邮件应用。
- 英文资源已检查，未另行运行英文界面实机验收。
- 使用实际 App 源码生成的独立设置回归窗口，未替换已安装应用。构建及快照沿用已有 `build/` 忽略规则。
- AGENTS.md：无需更新；本次沿用已有原生页面、ToolService 边界与构建命令。
