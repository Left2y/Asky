# 更新安装后的退出与重启

Date: 2026-10-11.

## 问题与修复

- 已安装的 0.0.7 下载、解压并验证 0.0.8 后停留在“正在安装…”。进程采样显示 `AboutSettings.install` 的 Swift 任务停在 `NSApplication.terminate` 的 AppKit 嵌套事件循环；替换助手持续等待主进程退出。
- `ApplicationTermination` 首次退出请求返回 `.terminateCancel`，让当前 Swift 任务结束、主执行器恢复调度。异步清理完成后再次调用 `terminate`，此时返回 `.terminateNow`。清理期间的重复退出请求不会跳过清理，也不会重复启动清理。
- AgentHost 原先用 task group 对不可取消的 `waitForExit` continuation 与超时进行竞速。超时获胜后，task group 仍等待未退出的进程，无法进入终止分支。现在独立升级任务在宽限期后发送 TERM，再等 500ms 发送 KILL；主路径等待真实退出后取消升级任务，并清理进程组。

## 已执行检查

```sh
python3 App/Tests/run-application-termination-regression.py
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
codesign --verify --deep --strict /Applications/Asky.app
git diff --check
```

- 原生回归负对照：旧 `.terminateLater` 实现从 Swift Task 触发退出后，3 秒内无法退出，测试结束该替身进程。
- 修复后的真实 AppKit 进程：从 Swift Task 发起退出，异步清理只执行一次；清理中再次退出被阻止；最终确认清理完成后成功退出。
- 替换回归：执行 ToolService 的实际替换脚本，等待原生进程结束后替换临时应用、删除暂存目录、启动另一个原生进程。此检查用替身 `open` 启动测试程序，不替换真实应用。
- 核心包测试全部通过；新增 `shutdownKillsRuntimeThatIgnoresShutdownAndTerm` 用不可取消的 continuation 模拟不响应 shutdown/TERM 的 runtime，0.730 秒内完成强制退出并清理运行状态。
- 完整 Debug App 构建通过。
- 现场恢复：普通退出快捷键未结束旧进程；确认旧进程路径及已准备的助手后，发送 TERM 结束卡住的 0.0.7。原有助手完成更新，`/Applications/Asky.app` 为 0.0.8，并经 LaunchServices 自动重新打开；旧进程和助手均已结束，暂存目录已删除，已安装应用签名校验通过。

## 边界

- 现场恢复使用已下载的原始 0.0.8，它不包含本次源码修复。本次未打包、发布或将 Debug 应用覆盖正式安装版；持久修复需要进入下一次 Release。
- 已覆盖本机 AppKit 退出、重复退出、无响应 runtime 与替换/重新打开链路；尚未通过新的 GitHub Release 在真实安装版执行修复后的完整下载更新，也未验证 macOS 15 实机行为。
- README 中英文同步退出清理行为与原生回归命令；AGENTS.md 的模块边界与已有开发规则仍适用，无需修改。
