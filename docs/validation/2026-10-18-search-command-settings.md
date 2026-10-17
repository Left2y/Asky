# 搜索指令设置验证

日期：2026-10-18

## 实现

- 设置 › 指令加入书签、链接、AI 搜索触发词配置，默认分别为 `bm`、`link`、`ai`，加空格进入模式。
- 三种搜索及既有网页指令可保存触发词、恢复默认；拒绝空白及与终端、其他指令、别名重名的触发词（不区分大小写）。旧偏好补默认值，新偏好存入现有 LocalStore。
- 网页指令启停仍以稳定预设 ID 保存，改触发词后仍使用原品牌图标。书签遵循 Chrome 数据源及读取授权；显式链接模式接受网址或域名。
- AI 模式只准备结果，Return 或 Command-Return 提交时去除触发词；无问题时不提交。空输入退格和 Escape 沿用已有退出模式逻辑。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：263 个测试通过，包含自定义搜索模式、空格提交、大小写、原始输入重建、退出和书签权限关闭场景。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --search-commands`：通过。验证旧设置、启停与持久化、自定义网页触发词、冲突校验、AI/链接模式、品牌身份，以及 AI 输入不提交、Return/Command-Return 提交的 prompt 不含触发词。
- 已查看真实 NSWindow 的浅色、深色及最小尺寸截图：`build/search-commands-light.png`、`build/search-commands-dark.png`、`build/search-commands-minimum.png`。文字、输入框、保存及恢复按钮均完整显示。
- `git diff --check`：通过。

## 边界

回归使用临时数据目录与 AI 提交回调，不向真实模型发送请求，不打开外部链接、不替换已安装应用。截图和回归构建沿用已有 `build/` 忽略规则。现有 Xcode 模拟器插件及 AppUpdater 捕获警告未阻止 macOS 构建与回归。首次直接使用 Command Line Tools 的 `swift test` 因缺少 Testing 模块失败，切换至 README 要求的完整 Xcode 后通过。

README 已同步中英文功能说明与回归命令；检查适用的根、App、KulaCore 指令及项目清单后，本次普通功能变更无需新增持久规则，AGENTS.md 保持不变。
