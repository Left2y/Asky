# 插件页辅助文字字号

- 官方插件说明、已安装插件的来源/版本/提交信息、仓库链接、操作按钮和处理状态统一使用系统 12 pt 字体。
- 保留原有颜色、控件尺寸和交互。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。首次未指定 Xcode 的运行因找不到 Testing 模块失败，切换 Xcode 后通过。
- 启动了新构建的 Debug 应用；computer-use 返回没有可检查的窗口，实际视觉验证未完成。
- README 与 AGENTS.md 无需更新：字号修正不影响使用说明、开发命令或架构边界。
- 工作区原有修改保留，提交仅包含本次字号修改及此验证记录。
