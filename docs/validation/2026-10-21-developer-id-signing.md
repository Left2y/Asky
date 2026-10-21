# Developer ID 正式签名配置（2026-10-21）

## 配置

- 已验证登录钥匙串中的 `Developer ID Application: Niall Young (V8GVW783CK)` 为有效签名身份，包含可用私钥。
- `project.yml` 中 Asky 与 asky-mcp 的 Release 使用该证书及 Team ID `V8GVW783CK`；Debug 保留 `Asky Local Signing`。
- 发布脚本要求 Developer ID Application，附安全时间戳，覆盖 Node、Mach-O 原生依赖、MCP Bridge 与旧 MCP 兼容入口；保留 bundle 和 runtime 的符号链接。
- 发布流程接入应用公证及票据装订，再生成更新 ZIP；DMG 单独签名、公证和装订，最终计算校验和。默认公证钥匙串配置名为 `Asky`。

## 已实际运行

- `security find-identity -v -p codesigning`：找到有效证书及私钥；名称与 SHA-1 解析检查通过。
- `xcodegen generate`：通过；生成工程两个 target 的 Debug / Release 签名配置检查通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Release -derivedDataPath build/DeveloperIDDerivedData build`：BUILD SUCCEEDED。该构建包含工作区已有的其他功能改动，只用于构建验证。
- 新构建的 Release 应用：`codesign --verify --deep --strict --verbose=2` 通过，Team ID 为 `V8GVW783CK`。进一步为两个 Release target 显式设置 `OTHER_CODE_SIGN_FLAGS = $(inherited) --timestamp`，重新生成工程与构建通过；确认最终应用具有 Apple 安全时间戳。
- 将此前 v0.1.15 的完整发布 bundle 复制到 `build/developer-id-validation/Asky.app`，使用当前脚本和正式证书重新签名；不替换 `/Applications/Asky.app`。深度严格签名校验通过，应用、两个 MCP 入口、Node、两个 Darwin 原生扩展与三个 esbuild 副本共 9 项均具有正式 Team ID、安全时间戳与 hardened runtime。
- 首次 Apple 公证返回 Invalid（提交 ID `508a8828-a7b2-4695-904e-4219b08c51c1`），指出三个无扩展名 esbuild 可执行文件缺少正式签名、安全时间戳与 hardened runtime。签名脚本改为根据 Mach-O 文件头扫描全部原生代码，并用 `file` 排除 FAT 魔数相同的非 Mach-O 文件。修正后扫描整个应用，全部 9 个 Mach-O 文件验证通过；三个 esbuild 副本实际执行 `--version` 均通过。详细 Apple 日志为 `build/developer-id-validation/app-notarization.details.json`。
- 正式签名后的随包 Node / AgentRuntime `hello`、`ready`、`shutdown` 协议冒烟通过。
- Mach-O 检测实际验证：接受无扩展名 esbuild，排除相同 FAT 魔数的 Java class、ELF 与脚本。
- Python 三个发布相关脚本的语法编译与 `package-release.py --help` 通过。
- 实际调用发布脚本，确认脏源码、自签名与 ad-hoc 三种条件均在打包前失败。
- `git diff --check` 通过。签名明细、runtime 输出与校验日志位于 `build/developer-id-validation/`，完整构建日志为 `build/developer-id-build.log`。
- 通过本机隐藏输入框录入 App 专用密码，使用 notarytool 的安全终端提示输入；Apple 返回 Credentials validated / Credentials saved to Keychain。`notarytool history --keychain-profile Asky` 认证通过。密码未写入聊天、仓库或凭据文件。

## 边界

- 修正后已重新提交 Apple 公证，提交 ID `faf3f305-bd90-424d-8d05-5aba54f30f0d`，回执为 `build/developer-id-validation/app-fixed-notarization.json`；当前仍为 In Progress，不能记为公证通过。票据装订、Gatekeeper 与 DMG 公证尚未验收。
- 未发布 GitHub Release、未安装应用、未测试权限连续性或真实 UI。工作区其他功能改动保留。
- 未修改 Swift 或 AgentRuntime 源码，因此未在本任务重复运行其功能测试套件。

参考：[Apple 公证说明](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[自定义公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)。
