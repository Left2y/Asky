# 系统应用显示语言修复

日期：2026-10-11

## 原因与修复

此前中文名进入检索索引，但显示名称通过 `Bundle.preferredLocalizations(from:)` 隐式选择，受宿主 App 的默认语言影响。系统设置的 loctable 还含有多平台变体；本机隐式选择结果为 `en_AU~appletv`，其名称是 `Sprocket`。

AppsProvider 现在显式使用 `Locale.preferredLanguages`。loctable 仅使用通用和 `~mac` 资源，Mac 字段覆盖同语言通用字段；同时按用户语言选择 lproj 名称。保留各语言 Mac 名称用于搜索，不硬编码应用列表。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：147 项测试通过。新增简体、繁体、英文显示名称测试，以及排除 Apple TV/iPhone 名称和 UTF-16 lproj 显示名称的检查。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 实际 LauncherWindowRegression 的 `--system-app-names` 模式：电话、备忘录、计算器、系统设置、音频MIDI设置、活动监视器、终端、日历的搜索及中文显示名称，在 Aqua / Dark Aqua 中全部通过。
- 查看真实 launcher 回归窗口截图 `build/launcher-system-names-NSAppearanceNameAqua.png`：首条名称为“系统设置”；路径仍为 `/System/Applications/System Settings.app`。

## 验证限制

原仓库回归脚本的固定源码清单未包含当前未提交设置改动所依赖的 SettingsPage；因此本次使用 `/tmp/asky-system-name-regression.py`，从原脚本派生，源码清单改为 App/Sources 中除 KulaHereApp 外的全部 Swift 文件，其余编译/运行逻辑相同。该临时脚本不进入仓库。

曾使用继承的开发目录运行原脚本，产生 SDK 26.5/27.0 不匹配；成功验证明确指定了 `/Applications/Xcode.app/Contents/Developer`。

已重启仓库 Debug App。产品本身的菜单栏窗口未完成 computer-use 输入检查；上述窗口验收由实际 launcher 回归窗口及截图完成。未打包 Release 或安装应用。

README: unchanged — 已描述应用自带本地化名称读取；本次修正已有行为，没有改变使用或构建步骤。
AGENTS.md: unchanged — 无模块、命令或持久规则变更。
