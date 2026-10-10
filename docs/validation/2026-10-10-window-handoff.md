# AI 与设置窗口焦点交接

## 问题及处理

仅将 AI 的 `.floating` 改为 `.normal` 没有处理 accessory App 的异步激活与钥匙串授权交接，设置窗口也仍使用浮动层级。

- AI 和设置统一由 `WindowPresentation` 发起一次性前台请求，保持 `.normal`，主动打开时移动到当前桌面，并参与普通主窗口调度。
- `orderFrontRegardless()` 只用于一次性调整普通层级内的顺序；App 激活通知只消费一次待聚焦窗口。失活、关闭或最小化会清除待聚焦请求。
- 系统密码授权开始前清除尚未完成的聚焦请求，授权期间不重排窗口，避免延迟激活通知抢走密码弹窗的 key focus。
- AgentHost 配置提供者改为异步；授权前后等待主线程回调，取消和失败也完成交接，然后才传播错误。
- 授权恢复不再依赖任务仍运行；只恢复授权开始时及完成时仍可见、未最小化的窗口。
- 从菜单栏打开 AI 前隐藏启动器。

## 已执行检查

- `Packages/KulaCore`：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，117 个测试、23 个套件通过。新增异步授权失败交接顺序测试。
- `xcodegen generate`：成功。
- README 中的 Debug `xcodebuild` 命令（带 `DEVELOPER_DIR`）：`BUILD SUCCEEDED`。
- 退出原 Debug App 并启动新构建，原 PID 45823，首次修复构建 PID 51008，最终构建 PID 54654。
- Orca computer-use 使用 PID 定位 accessory App，实际 AI 窗口 48424 与设置窗口 48430 均读取到 `layer: 0`。
- 在 AI、Finder、设置之间切换，Finder 返回实际焦点元素，AI 可重新聚焦，设置窗口可见且保持 layer 0。
- `git diff --check`：通过。

## 验证边界

真实钥匙串密码弹窗的输入、成功/取消/失败后窗口顺序尚未完成用户验收。上述真实窗口检查验证普通窗口层级及应用切换，不代表真实授权流程已全部通过。新增授权开始时清除待聚焦请求的最终构建已另行重启。全屏、Stage Manager、多桌面及授权期间主动关闭/最小化尚未实际逐项验收。

窗口语义参考 Apple 的 [orderFrontRegardless](https://developer.apple.com/documentation/appkit/nswindow/orderfrontregardless()) 和 [canJoinAllApplications](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications) 文档。
