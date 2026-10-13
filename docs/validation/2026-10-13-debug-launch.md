# Debug 启动修复

## 问题与修复

- 2026-10-13 20:19:39 的 `Asky` 崩溃记录报告 `DYLD / Library missing`：`Asky.debug.dylib` 被 Hardened Runtime 的库验证拒绝，原因是 `mapping process and mapped file (non-platform) have different Team IDs`。
- 主程序与 Debug dylib 都由 `Asky Local Signing` 签名，`TeamIdentifier=not set`。这是无 Team ID 本地证书与独立 Debug dylib 的启动兼容问题。
- 在 `project.yml` 的 Asky target / Debug configuration 设置 `ENABLE_DEBUG_DYLIB: NO`，将 Debug 代码直接链接到主程序，保留本地证书签名与 Hardened Runtime。
- 代价：App target 的 SwiftUI Previews 不可用。普通运行和 Debug 编译不依赖该功能；未在本次验证 LLDB 断点。
- 构建布局与 Previews 限制参考 [Apple 官方说明](https://developer.apple.com/documentation/xcode/understanding-build-product-layout-changes)。

## 实际执行的验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过；日志 `build/debug-launch-fix-build.log`，Xcode 自动清除旧 `Asky.debug.dylib` 和 `__preview.dylib`。
- `codesign --verify --deep --strict --verbose=2 build/DerivedData/Build/Products/Debug/Asky.app`：通过。
- `otool -L`：主程序不再依赖 `Asky.debug.dylib`。
- 通过 README 的 `open` 命令启动新包，PID 79748，启动时间 20:21:05，路径为本仓库 `build/DerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky`。
- 通过 CUA 绑定该完整 app 路径，实际读取 Launcher 窗口；按 Cmd+, 打开设置，读取到 `通用 — Asky 设置`，并检查窗口截图。进程持续运行，没有再次发生启动即退出。
- 本次只修改构建配置与文档，没有修改 Swift / AgentRuntime 源码，因此未重复运行核心包和 AgentRuntime 测试。

## 文档检查

- README 中英文同步补充 Debug 签名兼容配置与 Previews 限制。
- AGENTS.md unchanged：没有改变开发命令、模块边界或独立子项目。
