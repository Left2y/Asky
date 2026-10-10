# 再次打开应用显示启动器

## 修复

- `applicationShouldHandleReopen` 在设置窗口可见时仍返回设置；其他情况调用 `openLauncher()`，关闭剪贴板面板并显示启动器。
- 移除再次打开应用时隐式调用 `agentWindow.show()` 的行为。菜单栏 AI 入口和启动器主动提交 AI 请求的入口保留。
- README 中英文窗口行为说明同步更新。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 默认 `swift test`：失败，Command Line Tools 环境缺少 `Testing` 模块。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：145 个测试、28 个 suite 通过。
- `git diff --check`：通过。

## 验证范围

代码与 Debug 构建已验证。通过原生 UI 工具检查了运行中的窗口，但工具未能可靠触发再次打开应用事件，因此 Finder/Dock 的实际再次打开行为尚未完成现场验收。没有打包 Release 或安装到 Applications。

AGENTS.md 无需更新：命令、模块边界和持久开发规则未改变。构建产物沿用现有 `.gitignore`。
