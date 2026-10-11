# 搜索框计算补全与多币种汇率

日期：2026-10-11

## 行为

- 算术表达式继续由受限本地解析器处理；`1+1` 在原生输入框末尾显示浅色 `= 2`。后缀不进入输入绑定、IME 缓冲或选区；移动到表达式中间、选择文字或输入未完成表达式时隐藏。回车沿用计算结果的复制动作。
- `1美元`、`1 USD`、`100人民币` 等金额加单一币种触发多币种汇率列表。外币优先显示人民币；人民币转换为美元等其他货币。显式 `100 USD CNY` 保持单目标换算。
- 目标币种使用国家／地区旗帜，人民币为中国旗帜；欧元为欧盟旗帜。显示金额、本地化货币名称、ISO 代码、交叉汇率、ECB 日期及缓存状态。
- 一次列表使用同一份 ECB 数据快照。查询变更取消旧任务，等待 150ms 后才读取汇率；网络与缓存读写从 App 经 ToolService 进入汇率服务。离线使用有日期的缓存，无可用数据时不生成金额。
- 复用已有 `build/` 忽略规则；未打包 Release 或安装至 Applications。

## 已执行验证

| 检查 | 结果 |
| --- | --- |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore` | 全部测试套件通过，包含 CurrencyCompletionTests 的单币种、显式币种、错误输入、国旗覆盖与离线同快照换算 |
| `xcodegen generate` | 成功生成 Asky 工程 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build` | BUILD SUCCEEDED |
| README 中的 `xcrun swiftc` 原生输入框检查（含 EditMenu）及 `build/launcher-input-regression` | 通过；命令模式同步、选区保留、原生粘贴不回归 |
| `python3 App/Tests/run-launcher-calculation-regression.py` | Aqua、DarkAqua 均通过；真实 NSTextView 插入表达式、浅色后缀、光标中途隐藏、人民币优先、人民币反向换算、显式单币种与旧查询取消 |
| ECB XML 端点的实际 HTTPS 下载 | 成功返回 XML，下载数据日期为 2026-10-09；不以此下载取代缓存测试 |
| 原生窗口图像人工检查 | 已检查下列四张图片，确认补全文字、旗帜与币种行在浅色／深色外观下显示 |
| `git diff --check` | 通过 |

原生回归使用临时独立数据目录和固定汇率快照：2026-10-08，EUR/USD=1.1，EUR/CNY=7.7。因此截图中的 `1 USD = 7 CNY` 是确定性的测试数据，不表示当日行情。测试实际创建 LauncherPanel、SwiftUI 树和 AppKit 输入编辑器，并在退出时清理临时数据；截图为窗口内容捕获，不作为真实桌面背景玻璃采样的验收。

截图保存在被忽略的构建目录：

- `build/calculator-NSAppearanceNameAqua.png`
- `build/calculator-NSAppearanceNameDarkAqua.png`
- `build/currency-NSAppearanceNameAqua.png`
- `build/currency-NSAppearanceNameDarkAqua.png`

原生回归脚本显式选择当前 Xcode 的 macOS SDK，以匹配 Debug 构建产物；本机默认 swiftc SDK 与 Xcode SDK 不一致。验证时构建与原生回归串行执行，避免产物在链接期间被修改。

## 文档与 Git

- README: updated；中文／英文同步使用方式及实际原生回归命令。
- AGENTS.md: unchanged；本次属于现有 DirectActions、ToolService 和 Launcher 内的功能，没有新增独立子项目或开发规范。
- 工作区开始时已有大量修改，包括此次涉及的 LauncherModel、LauncherView、LauncherSearchField 和 README。隔离补丁的只读检查在 LauncherModel 与 LauncherView 失败，因此未生成混合或不完整提交；保留已有暂存区与工作区内容。
