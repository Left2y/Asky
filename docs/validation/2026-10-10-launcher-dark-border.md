# 启动器暗色边框

- 暗色自定义渐变描边的白色透明度由 0.80 / 0.24 / 0.32 降至 0.18 / 0.06 / 0.04，减轻与原生玻璃轮廓叠加后的亮灰色边线。
- 浅色及辅助功能高对比度、减少透明度分支未变。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：140 tests / 28 suites passed。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 实际窗口检查：以现有 LauncherWindowRegression 编译配置加载真实 LauncherView / LauncherPanel，独立临时数据库、darkAqua 外观，通过 computer use 查看空输入原生窗口截图；确认顶部轻微高光、底部边线减弱。自动化快捷键未成功唤起主 App 的启动器，因此这项视觉检查使用独立原生预览。
- README 与 AGENTS.md 检查：此次仅调整视觉参数，无使用方式、命令或架构边界变更，保持不变。
- 临时编译产物位于已忽略的 build/ 中；预览脚本及 App 位于 /tmp，未纳入提交。
