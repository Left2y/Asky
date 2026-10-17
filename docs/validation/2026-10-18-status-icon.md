# 菜单栏图标小尺寸修正

将完整歪头小伙伴的缩小位图替换为菜单栏专用单色矢量：规整的圆顶轮廓、圆眼与简化笑脸，18 × 18 pt 画布，图形上下留白。`Mark.svg` 与资源目录中的 SVG 保持一致，使用透明镂空五官与系统 template 着色。

实际执行：

- `xcodegen generate` 成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build` 成功。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 成功。
- 用临时 AppKit 预览进程从本次构建的 Asky.app 加载编译后的 `StatusIcon`，按生产代码的 18 pt、template、squareLength 配置创建真实 NSStatusItem。实际菜单栏截图为 `build/status-icon-menubar.png`：新图标在旧版图标左侧，形状、镂空与居中正常。预览进程自动退出，不启动 AppModel 或系统工具。

限制：仅检查了当前系统菜单栏外观，未切换系统深浅色；未替换 `/Applications/Asky.app`。构建包含工作区原有改动，本次提交只包含菜单栏图标修正。临时预览与截图沿用现有 `build/` 忽略规则。

README 无需修改：仍然使用已记载的单色 `Mark.svg`，安装、操作和构建命令不变。AGENTS.md 无需修改：没有新增命令、架构边界或持久约定。
