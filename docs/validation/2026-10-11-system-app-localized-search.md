# 系统应用中文名称检索

## 原因与修复

本机 Phone.app 的中文名称存放于 Contents/Resources/InfoPlist.loctable。应用索引原先只读取 Info.plist、localizedInfoDictionary 和各 lproj 下的 InfoPlist.strings，漏掉了 loctable。

新增读取语言字典中的 CFBundleDisplayName / CFBundleName，保留所有语言名称供检索，并使用偏好语言的名称作为显示名称。不添加硬编码中文应用名单，不索引版权或其他界面文案。

## 实际验证

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：146 项测试通过，包含 XML/binary loctable、简体/繁体/英文名称和非名称字段排除。
- `xcodegen generate`：通过。
- README 中的 Debug xcodebuild 命令：BUILD SUCCEEDED。
- `python3 App/Tests/run-launcher-window-regression.py --system-app-names`：真实 AppsProvider 和 LauncherModel / LauncherController 使用隔离数据目录，浅色与深色模式均检索到电话、备忘录、计算器、系统设置对应的系统 App。
- 检查 build/launcher-system-names-NSAppearanceNameDarkAqua.png：输入电话后显示 Phone.app 结果。测试进程偏好语言为英文，结果标题为 Phone，中文搜索名称仍有效。
- 本机真实索引独立检查亦匹配上述四个系统应用。

首次测试出现临时目录 /var 与 /private/var 字符串比较差异，改为验证匹配应用文件名后通过。原生回归脚本原先漏编译 WindowPresentation.swift（SettingsShortcut 定义），已补齐依赖后通过。

构建与截图由既有 build/ 忽略规则覆盖，未打包或安装 Release。README 同步中英文能力说明和验证命令；AGENTS.md 无持久规则变化。
