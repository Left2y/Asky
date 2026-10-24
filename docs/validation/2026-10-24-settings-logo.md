# 设置页 Logo 尺寸修正

- 问题：关于页 Logo 使用 56 pt 布局尺寸并叠加 1.22 倍缩放，显示约 68 pt，超出文字块应有比例。
- 修改：保留 AskyLogo 资源，使用 40 × 40 pt，移除额外缩放。
- 通过：`xcodegen generate`。
- 通过：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/LogoDerivedData build`。
- 通过：在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，退出码 0。
- 原生视觉检查：使用现有 Debug 产品，通过 `ASKY_DERIVED_DATA=build/DerivedData python3 App/Tests/run-settings-regression.py --preview` 重新编译当前 App 源码；启动 `build/SettingsRegression.app`，实际点击 About Asky。截图确认 Logo 为 40 pt，与名称、版本信息垂直居中，无溢出或遮挡。
- 覆盖范围：本次检查浅色、英文原生设置预览；未运行整套设置回归，未单独检查深色与中文显示。预览包显示 Version 0，不代表正式应用版本。
- README 与 AGENTS.md 检查：本次仅修正现有界面尺寸，未改变命令、使用流程或架构，均无需更新。
- 构建与预览产物由现有 `.gitignore` 的 `build/` 规则排除。
