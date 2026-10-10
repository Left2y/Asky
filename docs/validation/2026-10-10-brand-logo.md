# KulaHere Logo 与菜单栏图标

- 使用用户选定的白底渐变光带 Logo，原图保存于 `App/Branding/Logo.png`。
- `AppIcon.appiconset` 提供 macOS 16/32/128/256/512 pt 的 1x/2x PNG；采用圆角白底与透明外边距。
- `StatusIcon.imageset` 使用原 Logo 的单色轮廓，提供 18 pt 的 1x/2x/3x 透明模板图像；通过 AppKit 模板着色适配菜单栏外观。
- `project.yml` 设置 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`。菜单栏保留原菜单功能与 KulaHere 无障碍标签。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：145 tests / 28 suites 通过。首次未指定 Xcode 工具链的运行因缺少 Testing 模块失败，改用完整 Xcode 工具链后通过。
- 编译产物检查：`CFBundleIconFile=AppIcon`，`Resources/AppIcon.icns` 存在；使用 AppKit 从构建 Bundle 加载 `StatusIcon`，确认 `isTemplate=true`、尺寸 18×18 pt。
- 图像预览检查：应用图标圆角白底；菜单栏轮廓在浅色/深色底上的黑/白预览可辨认。
- 已结束旧 Debug 进程并通过 computer use 重新打开构建后的应用，观察到 AI 窗口。截图仅包含窗口，未实际观察到系统菜单栏；菜单栏实屏效果、点击和明暗切换仍待验收。
- 未打包 Release 或安装到 Applications。

## 文档与工作区

README 同步中英文图标说明与 Logo 展示。AGENTS.md 无需变更：构建命令与架构边界保持一致。临时生成与验证文件位于已忽略的 `build/branding/`。保留任务开始前的其他修改。
