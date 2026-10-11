# Asky 全局名称统一

## 范围

- Xcode 工程、App target、scheme 和 Swift 入口统一为 Asky；构建命令使用 Asky.xcodeproj / Asky。
- MCP 源码目录、target、产物和协议 serverInfo 使用 asky-mcp / asky；设置导出的配置使用 asky 及 ASKY_MCP_CREDENTIAL。
- AgentRuntime 包名、ready 标识与 provider 名称、系统授权错误、钥匙串错误、MCP 连接错误与执行回执、源码注释和测试数据统一使用 Asky。
- 当前产品与架构文档、README 中英文命令和名称同步；历史 validation 文档保留当时实际执行的名称与命令。原始 Figma URL 不改写。
- 兼容既有安装：保留 app.kulahere.KulaHere、app.kulahere.credentials、Application Support/KulaHere、kulahere.sqlite 与原 MCP socket 路径。Bridge 同时支持新旧环境变量；App 包内 kulahere-mcp 为 asky-mcp 的兼容符号链接。仓库目录没有移动。

## 实际验证

- AgentRuntime：npm test 通过，4 tests / 0 fail。
- MCPBridge：DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build 通过，生成 asky-mcp。
- KulaCore：DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 通过，全部测试产品完成；bridgeBinaryEndToEnd 的 ASKY、KULAHERE 两个参数用例均通过，协议 serverInfo.name=asky。
- xcodegen generate 通过，生成 Asky.xcodeproj。
- DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build：BUILD SUCCEEDED。
- 构建产物 CFBundleName / CFBundleDisplayName / CFBundleExecutable 均为 Asky；CFBundleIdentifier 保持 app.kulahere.KulaHere；兼容 MCP 符号链接指向 asky-mcp。
- 退出旧 Debug 运行实例后，最新 Debug 构建启动，PID 43103，可执行路径为 Asky.app/Contents/MacOS/Asky。cua 原生 AX 状态显示 App: Asky，菜单栏名 Asky。设置快捷键操作被工具的用户状态变更保护阻止，未声称验证设置页。
- git diff --check 通过。新生成工程与 entitlements 已增加精确忽略规则，其余构建输出复用现有忽略规则。
- README: updated，同步中英文命令、工程名称和 MCP 兼容说明。
- AGENTS.md: unchanged，现有 root 已为 Asky；子项目边界与验证要求未变化。
- Git 未提交：入口文件重命名及 README、project.yml、App 设置等必要改动与任务开始前的未提交内容交叠；不创建混合或不完整提交。没有打包或安装 Release。

## 补提交验证

上面的“Git 未提交”是此前执行时的状态。本次从 HEAD 与工作区改动中提取改名内容，按文件与内容分别暂存；本地化、编辑菜单、剪贴板预览/阴影、汇率等其他修改保留在工作区。将暂存树导出到独立临时目录后运行验证，确认提交本身可构建，不依赖未提交功能。

- AgentRuntime：`npm test` 通过，4 tests / 0 fail，复用现有 node_modules。
- MCPBridge：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --scratch-path /Users/niallyoung/orca/KulaHere/MCPBridge/.build` 通过。
- KulaCore：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /Users/niallyoung/orca/KulaHere/Packages/KulaCore/.build` 通过；新旧 MCP 环境变量的两个参数用例均通过。临时快照内 MCPBridge/.build 链接到上述 Bridge 构建目录，使端到端测试实际运行。
- App：`xcodegen generate` 通过；`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData -clonedSourcePackagesDirPath /Users/niallyoung/orca/KulaHere/build/DerivedData/SourcePackages build` 通过，BUILD SUCCEEDED。
- Python 实际检查构建产物 Info.plist：CFBundleName / CFBundleDisplayName / CFBundleExecutable 均为 Asky；CFBundleIdentifier 为 app.kulahere.KulaHere；旧 MCP 命令符号链接指向 asky-mcp。
- `git diff --cached --check` 通过。Asky.xcodeproj 与 App/Asky.entitlements 精确忽略规则均通过 `git check-ignore -v` 检查；临时验证产物位于项目外。
- README: updated，中英文名称、命令与 MCP 兼容说明纳入改名提交；语言及编辑菜单说明留在工作区。
- AGENTS.md: updated，仅同步产品名称，保留项目和子项目边界及检查要求。
- 本次未重新启动实际 App 或进行 UI 验收；未打包、安装 Release 或推送远程。
