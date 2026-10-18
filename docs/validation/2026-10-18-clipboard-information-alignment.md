# 剪贴板详情值右对齐

右侧预览底部的信息区保留左侧标签的左对齐，来源（含图标）、类型、尺寸、大小与复制时间统一靠信息区右边缘对齐。值列占满剩余宽度，多行值也采用右对齐。

## 验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过，包含布局切换、设置持久化、旧配置默认值、选中保留、筛选、固定和复制。
- 查看实际窗口截图 `build/clipboard-layout-list-image.png` 与 `build/clipboard-layout-list-text.png`：来源图标与名称、文本及图片详情值均右对齐，标签保持左对齐，日期与尺寸无截断。截图与回归产物沿用现有 `build/` 忽略规则。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：未通过；`PluginTests.nativeWorkerRoundTripAndPolicy` 缺少本地生成文件 `AgentRuntime/dist/src/plugin-runner.js`，产生运行器存在性与插件输出断言失败，未涉及本次 UI 修改。

README 与 AGENTS.md 无需修改：本次仅调整详情值排版，不改变使用方式、开发命令或架构边界。
