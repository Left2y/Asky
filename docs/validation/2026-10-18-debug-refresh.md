# Debug 构建刷新验证

- 时间：2026-10-18 00:05（Asia/Shanghai）。
- 基于当前工作区构建，保留原有未提交改动；本次未修改源码或版本配置。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：退出码 0，`BUILD SUCCEEDED`。日志：`/tmp/asky-debug-refresh-build.log`。
- `cd AgentRuntime && npm run build`：退出码 0。
- `codesign --verify --deep --strict build/DerivedData/Build/Products/Debug/Asky.app`：退出码 0。
- 使用绝对路径 `open -n /Users/niallyoung/orca/Asky/build/DerivedData/Build/Products/Debug/Asky.app` 启动；通过进程列表确认 PID 22984 的可执行路径为该 Debug bundle，启动时间 00:05:34。
- 本地还有 `DeepSeekDerivedData`、`ExtraCommandsDerivedData`、`CopyFileDerivedData` 下的旧 Debug 副本。
- 默认 Debug 的 `CFBundleShortVersionString` 仍为 `project.yml` 中固定的 `0.1.0`；`/Applications/Asky.app` 为 `0.1.6`。两者版本号不能作为 Debug 源码新旧的判断依据。
- 本次仅验证构建、签名与进程路径，未执行功能回归或界面验收。
