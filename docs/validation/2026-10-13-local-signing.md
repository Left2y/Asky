# 固定本机签名验证

日期：2026-10-13。

## 实际完成

- 创建 `Asky Local Signing` 自签名代码签名证书，登录钥匙串保存私钥；用户级信任仅用于 Code Signing。Subject 和 Issuer 均只有 `CN=Asky Local Signing`，未填姓名、邮箱或组织。有效期至 2036-10-10。
- 证书 SHA-1：`BBCC4AB3786640961FFD5BF63808AD00761AFB3B`（公开标识，不是私钥）。重复执行 `python3 scripts/setup-local-signing.py` 保持该身份不变。
- `xcodegen generate` 和 Debug 构建通过：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/LocalSigningDerivedData build`。
- `python3 scripts/signing.py build/local-signing-check/Asky.app` 对已安装 0.0.18 的副本签名，包含 MCP Bridge、Node.js 和 Mach-O `.node` 模块；`codesign --verify --deep --strict` 通过。
- 将副本的 `CFBundleVersion` 改为 19 后重新签名：CDHash 不同，designated requirement 相同；使用原版本 requirement 执行 `codesign --verify --strict -R` 检查新副本通过。该副本仅用于身份校验，不是发布版本。
- 新签名的内置 AgentRuntime 完成协议 v2 hello → ready → shutdown，进程退出码 0。
- 用 `ditto` 创建 ZIP 并解压回读，解压后的应用通过深度签名检查和原版本身份要求检查。
- 签名工具明确拒绝 ad-hoc (`-`) 和不存在的身份。
- 本机 `/Applications/Asky.app` 的 0.0.18 已切换新签名并重新启动；安装路径签名检查通过，回读进程 PID 为 17964。

当前应用身份：

```text
identifier "app.kulahere.KulaHere" and certificate leaf = H"bbcc4ab3786640961ffd5bf63808ad00761afb3b"
```

## 产物与边界

- 本地日志、构建和 ZIP 位于 `build/`，沿用既有忽略规则。旧安装备份为 `build/local-signing-check/Asky-before-local-signing.app`。
- 临时 PEM、私钥及 PKCS#12 文件已随临时目录删除；没有进入仓库或安装包。
- 本次验证了共享打包签名逻辑和 ZIP 往返；未执行完整 DMG 发布打包、Apple 公证或 GitHub 发布。现有 GitHub 0.0.18 资产仍为旧 ad-hoc 签名。
- 未实机验证从已授权的自签名版本升级后，辅助功能、屏幕录制、自动化、日历等各项权限是否保留。从旧 ad-hoc 切换到新身份可能需要重新授权一次。
- 没有修改 Swift 或 AgentRuntime 源码；未运行 Swift/Runtime 单元测试。Debug 构建及内置 Runtime 的启动检查不能代替系统权限验收。
