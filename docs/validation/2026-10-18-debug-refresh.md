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

## Dock 图标补充验证（00:06）

- 用户实屏仍显示旧的厚白框图标，前述构建和进程验证未覆盖此问题。
- 检查当前 Debug 包，`CFBundleIconFile`、`CFBundleIconName` 均为 `AskyNative`，存在对应 ICNS；运行路径仍是默认 Debug 包。
- 对 Debug bundle 执行 `touch`，使用系统 `lsregister -f` 刷新应用注册，再以 `killall Dock` 重启 Dock，均退出码 0。
- 使用 `screencapture -x` 截取实际桌面，目视确认 Dock 右侧运行中的 Asky 已显示深蓝底的新小伙伴图标，旧的厚白外框已消失。截图：`../../build/debug-refresh/dock-after-refresh.png`（本地产物，沿用 `build/` 忽略规则）。
- 本次无需改动图标源码、README 或 AGENTS.md；未替换安装版。
