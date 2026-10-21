# 旧签名凭据自动迁移

## 行为

- Keychain 优先读取 `<原 service>.signed.v1` 的当前签名记录。仅在该记录不存在时读取旧 service；授权取消或读取失败不会写入新记录。
- 旧凭据首次成功读取后，自动在新命名空间创建由当前应用拥有的记录；无需用户为旧记录选择“始终允许”。首次旧记录读取仍可能需要 macOS 系统确认，无法静默绕过。
- 迁移只新增，不覆盖同时保存的新 Key；失败仍返回已成功读取的值，并保留旧记录，后续读取重试。旧记录不自动删除、不修改其 ACL；读取仍使用钥匙串默认的应用信任规则，没有开放给任意应用。
- 新保存优先新增，已存在时原位更新，避免先删后写导致写入失败丢失原值。显式删除覆盖两个命名空间；接口原有的删除状态忽略行为未改变。
- 原 service 仍保留，回退到不支持迁移的旧版本只能看到旧凭据，不能看到迁移后新保存的值。

## 实际检查

- 通过：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`，292 个测试通过；新增合成凭据测试覆盖旧记录发现、迁移后独立读取、新值与更新优先、删除后不回退到旧值。随机 service 与测试后清理，不访问真实凭据。
- 通过：`xcodegen generate`。
- 通过：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DebugSigningDerivedData build`。
- 通过：`codesign --verify --deep --strict --verbose=2 build/DebugSigningDerivedData/Build/Products/Debug/Asky.app`。
- 通过：`git diff --check`；中英文 README 同步迁移说明。AGENTS.md 保持不变，继续遵循原有凭据存储和验证边界。
- 产物沿用现有 `build/` 与 `Asky.xcodeproj/` 忽略规则。

## 验证限制

未读取、迁移或打印用户真实 API Key，未自动操作真实钥匙串授权弹窗；未验证旧签名进程到新签名进程、重启或重新构建后的完整 UI 路径。因此合成凭据与构建通过不等于真实弹窗验收。未运行 AgentRuntime 测试（无相关修改）、Release 打包或公证。构建包含工作区已有功能改动，本次提交不包含那些改动。

参考：[Apple SecAccessCreate](https://developer.apple.com/documentation/security/secaccesscreate(_:_:_:)) 说明默认新记录信任创建它的应用；迁移通过新记录建立应用归属，不改写旧 ACL。
