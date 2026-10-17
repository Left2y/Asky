# 关于作者链接验证

- GitHub、X 的 SwiftUI `Link` 显式使用 `.buttonStyle(.link)` 和 `.foregroundStyle(.link)`，使网址呈现原生蓝色链接；继续通过已有的 `openURL` 环境处理器调用 `ToolService.openLauncherURL`。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，258 项 Swift Testing 测试。
- 用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --preview` 启动新编译的原生预览，进入“关于作者”，目视确认 GitHub、X 与邮箱一致显示为蓝色链接。
- 通过 Orca computer-use 分别点击 GitHub、X 链接，读取 Chrome 地址栏确认打开 `github.com/Niall-Young` 和 `x.com/NiallxYoung`；对应标签标题为 `Niall-Young (Niall Young)`、`🍙饭团儿 (@NiallxYoung) / X`。
- README 与 AGENTS.md 无需修改：修复已有链接样式，不改变使用方法、开发命令或架构边界。
- 工作区已有其他设置页改动；本任务只提交 `AuthorSettings.swift` 与本验证记录。预览及构建产物由现有 `build/` 忽略规则覆盖。
