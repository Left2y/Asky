# 关于 Asky 与应用内更新

Date: 2026-10-11.

## 变更

- 设置侧边栏新增“关于 Asky”（`SettingsPage.about`），显示版本号、项目链接和“软件更新”分组。
- 更新逻辑位于 `Packages/KulaCore/Sources/ToolService/AppUpdate.swift`，App 只调用 ToolService：
  - `checkForAppUpdate()` 读取 `https://api.github.com/repos/Niall-Young/Asky/releases/latest`，优先选取名称含 `macos` 的 ZIP 资产；去掉 `v` 前缀后按数字分段比较，仅当 Release 版本高于当前版本时提示更新。
  - `prepareAppUpdate(_:)` 下载 ZIP，若存在同名 `.sha256` 则校验，`ditto` 解压，确认 bundle identifier 一致并通过 `codesign --verify --deep --strict`，随后启动独立 `/bin/sh` 助手。
  - 助手等待 Asky 进程退出，把旧包改名为备份，移入新包后删除备份，失败则还原旧包，最后 `open` 重新打开。暂存目录与已安装应用位于同一卷。
- 临时转移路径、应用目录不可写时直接报错，不尝试替换。
- 新增界面与错误文案已加入 en / zh-Hans `Localizable.strings`；README 与 PRIVACY.md 已补充。

## 已执行检查

```sh
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
python3 App/Tests/run-settings-regression.py
plutil -lint App/Resources/*/Localizable.strings
```

- 核心包测试全部通过，含新增 `AppUpdateTests`（Release JSON 解析、缺少安装包、仅较高版本视为更新、校验和解析与 SHA-256）。
- Debug 构建通过；设置回归通过，并生成 `build/settings-{light,dark}-about.png`。
- 在临时目录中用替身进程实测替换脚本：等待进程退出后旧包被新包替换，备份与暂存目录均已删除。

## 未验证

- 未在已安装的 Release 包中完整执行“检查 → 下载 → 替换 → 重新打开”，也未在需要管理员权限的安装位置测试。
- 开发版本号为 0.1.0，高于最新 Release 0.0.2，因此开发版显示“已是最新版本”。
