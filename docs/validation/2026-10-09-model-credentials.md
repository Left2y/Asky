# 模型凭据读取与启动错误修复（2026-10-09）

## 原因与范围

用户发送消息后看到 `无法启动 AI 运行时：notConfigured`。只读检查显示 SQLite 中存在 DeepSeek 地址、模型名及凭据引用，钥匙串中也存在对应账户的元数据；没有读取或打印实际 Key。原代码把读取失败和缺少凭据都转成 nil，因此该提示无法证明模型未配置。截图这次失败的确切 OSStatus 已被旧代码丢弃，无法回溯确认。

## 修改

- AgentHost 配置提供者允许抛出错误，展示本地化错误，区分未配置模型与缺少 Key。
- App 非交互读取遇到需要授权时，使用默认钥匙串交互授权路径重试；不再将交互失败吞成 nil。成功或失败后均请求恢复仍在进行的对话窗口。
- AI 提交只提前检查模型配置，凭据可用性由启动时的实际读取决定，避免元数据查询失败误报未配置。
- 设置页不再自动读取回填 Key；留空保存保留原账户的 Key，首次保存仍要求提供 Key。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：116 个测试、23 个 suite 通过。
- 回归覆盖：凭据错误不启动进程、授权错误原样显示、授权失败后重新提交可成功、错误分类及独立合成凭据的交互默认读取与非交互读取。测试凭据使用随机 service 并清理，没有改动用户凭据。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：成功。
- 正常退出旧 Debug App 并打开新构建，核对新进程；未打包 Release 或安装到 Applications。

## 验证限制

本次未操作真实模型 Key 的系统授权弹窗，也未代用户提交云端对话。用户的实际钥匙串授权和 DeepSeek 回复仍需在新进程重新发送消息验证。设置页的空值保留路径已构建并进行代码审阅，未进行界面自动化。
