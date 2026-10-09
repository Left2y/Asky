# 钥匙串授权与对话窗口验证（2026-10-09）

## 问题与已观察结果

用户报告：发起对话后出现密码验证弹窗，验证后入口消失，无法看到回复。

本次检查时 App 仍在运行，没有发现 KulaHere 的崩溃报告。通过原生窗口读取可见：最新的“你好”已有模型回复。密码验证后的实际窗口焦点变化未在修复前完整录制，因此不能把用户报告的所有细节认定为已复现。

代码中存在两项相关问题：从启动器提交时，先执行 `model.send()`，之后才显示 AI 窗口；`isModelConfigured` 在主线程读取 Key，AgentHost 启动时又读取一次。钥匙串读取可能阻塞并弹出系统授权，Apple 的 [SecItemCopyMatching 文档](https://developer.apple.com/documentation/security/secitemcopymatching(_:_:)) 也明确要求避免在主线程执行可能阻塞的读取。

当前 Debug App 使用 ad-hoc 签名，Key 最初由本地辅助程序创建。系统仍可能要求为实际 App 授权读取；本次没有修改钥匙串访问控制或关闭系统验证。

## 修复

- 先显示并激活 AI 窗口，再处理提交。
- 配置检查仅查询钥匙串元数据，使用禁止交互的认证上下文，不读取密钥正文。
- AgentHost 在主线程之外先尝试非交互读取；确需授权时执行交互读取，并在完成后恢复仍在进行的对话窗口。
- 钥匙串读取保留“凭据不存在”与“需要认证 / 访问失败”的区别，Key 仍只经原有宿主通信交给 Runtime。

## 实际运行检查

| 检查 | 结果 |
| --- | --- |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`） | 103 个测试、21 个 suite 通过 |
| 新增钥匙串回归测试 | 使用独立随机 service 与合成凭据；覆盖不存在、指定账户元数据、其他账户隔离、非交互读取与删除后的状态；测试结束后清理测试条目 |
| `xcodegen generate` | 成功 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build` | 成功；有工具链的 Simulator 版本提示及未使用 AppIntents 的元数据提示，没有 App 编译错误 |
| 重启实际 Debug App | 原进程退出，新进程启动；没有打包 Release 或安装到 Applications |
| 用户完成真实系统授权后测试 | 用户确认“验证后看到回复” |
| 授权后的原生窗口回读 | `KulaHere AI` 窗口可见；用户随后继续进行工具对话，窗口展示完整模型回复，任务结束后“新对话”恢复可用 |

后续工具对话中，日历操作返回“未获得日历完全访问权限”，模型正确说明操作失败。本次没有修改日历授权或创建日程；该权限与钥匙串授权分别管理。

## 待验证

拒绝或取消钥匙串授权、手动关闭窗口期间完成授权，以及每次重新构建后的授权行为尚未逐项验证。当前通过的是用户完成真实授权后窗口可见并能继续对话的路径。
