# Debug 使用正式 Developer ID 签名

- 修改：`project.yml` 中 Asky 与 asky-mcp 的 Debug、Release 共用 Developer ID Application 身份与 Team ID `V8GVW783CK`；本机 `scripts/signing.py` 默认身份同步。保留 Debug 单可执行文件布局；Release 时间戳设置保留。
- 通过：`security find-identity -v -p codesigning` 确认本机存在有效的正式签名身份。
- 通过：`xcodegen generate`。
- 通过：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DebugSigningDerivedData build`。
- 通过：`codesign --verify --deep --strict --verbose=2 build/DebugSigningDerivedData/Build/Products/Debug/Asky.app`。
- 通过：对 Debug 主应用和包内 `asky-mcp` 执行 `codesign -dvv -r-`，两者 Authority 均为 `Developer ID Application: Niall Young (V8GVW783CK)`，TeamIdentifier 均为 `V8GVW783CK`；主应用 designated requirement 使用 Apple 锚、bundle identifier 和 Team ID。
- 通过：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Release -showBuildSettings`，两个目标仍使用同一正式身份；本次未重新构建或打包 Release。
- 通过：`scripts/signing.py` 的 Python AST 语法检查与 `git diff --check`。
- 未验证：实际读取模型凭据、用户授权后反复构建是否还弹钥匙串提示；从旧自签名身份切换后可能需要重新授权。未修改钥匙串权限、读取秘密、安装或启动本次产物，也未执行公证。
- 本次仅改构建配置、Python 默认值和文档，未修改 Swift 或 AgentRuntime 源码，未运行它们的测试。构建包含工作区既有功能改动，不将其纳入本次提交。
- 构建产物沿用已有 `build/` 和 `Asky.xcodeproj/` 忽略规则。
