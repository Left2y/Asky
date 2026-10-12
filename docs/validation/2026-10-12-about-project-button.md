# 关于页项目入口按钮

- 将 GitHub 项目入口改成左侧说明、右侧原生“前往”按钮；英文为 “Go”。继续使用原有项目 URL。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 视觉检查使用 `build/about-preview` 内的临时原生预览，直接编译当前 `AboutSettings.swift` 并链接 Debug 产品；确认左侧黑色说明与右侧按钮布局。由于工作区另有并行构建及应用重启，完整 App 窗口不作为本次视觉通过证据。
- 在预览窗口点击右侧“前往”，回读 Chrome 地址栏为 `github.com/Niall-Young/Asky`。
- README：无需修改，此次仅调整现有入口样式，不改变使用流程或开发命令。
- AGENTS.md：无需修改，现有原生界面、系统能力边界与验证要求仍适用。
