# 关于页 GitHub 入口布局

- 将「在 GitHub 查看项目」按钮放入 Logo、名称和版本所在的 HStack，删除原来的独立 cell 与分隔线；系统打开 URL 仍经过 ToolService。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 原生窗口：从本次构建复制到 `/tmp/Asky-about-preview.app` 后运行，PID 92768，版本 0.1.0（1）；打开「关于 Asky」并检查深色窗口截图，确认按钮与 Logo 同行、没有下方独立 cell，文字未截断。浅色窗口未完成验证；未点击 GitHub 按钮验证浏览器跳转。
- README: unchanged；本次仅调整关于页布局，使用方式、命令和能力声明未改变。
- AGENTS.md: unchanged；没有改变持久开发指令、模块边界或工作流程。
