# 应用搜索结果启动时的主线程阻塞

用户反馈：选中应用搜索结果后打开其他 app 时，启动器偶尔留在屏幕上卡住；截图中的目标为钉钉。

## 定位与参考

正在运行的正式版为 `/Applications/Asky.app`，版本 0.2.5（45）。两次进程采样时主线程都已回到事件等待，没有捕获用户那次卡住的堆栈。附近日志中存在 AttributeGraph 的依赖循环报错，但不能据此认定它就是根因。

代码中的确定性风险：普通应用结果在主线程直接调用同步 `NSWorkspace.open(URL)`，返回后才隐藏启动器；应用别名通过 ToolService 调用同一个同步 API。普通结果还在隐藏前同步写入活动记录。

按用户指定检查 TinyCast 的提交 `6029038ff3b2043077b7105286152d99a893047a`：

- [LauncherCoordinator](https://github.com/abue-ammar/tinycast/blob/6029038ff3b2043077b7105286152d99a893047a/Tinycast/Features/Launcher/UI/LauncherCoordinator.swift#L148-L152) 先隐藏面板，再启动应用。
- [AppLauncher](https://github.com/abue-ammar/tinycast/blob/6029038ff3b2043077b7105286152d99a893047a/Tinycast/Features/Launcher/Service/AppLauncher.swift#L5-L10) 使用异步 `openApplication(at:configuration:completionHandler:)` API，应用结果禁用运行副本替代，保证打开选中的路径。
- [PaletteWindowController](https://github.com/abue-ammar/tinycast/blob/6029038ff3b2043077b7105286152d99a893047a/Tinycast/Palette/PaletteWindowController.swift) 保留面板与界面树，隐藏时清理重缓存。Asky 继续采用隐藏时释放界面树的既有策略。

## 修改

普通应用结果与应用别名统一由 ToolService 异步启动，禁用运行副本替代。等待当前输入事件回调结束后先隐藏面板，再提交启动请求；活动记录写入移至后台。隐藏时先卸载界面树，再重置搜索状态。启动失败显示包含目标名称和系统错误的原生提示，不把迟到结果写回新的搜索会话。

Debug 提醒预览的应用启动调用同步适配新的异步签名。未改普通文件、网址、窗口切换或插件执行行为。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，最终日志 `/tmp/asky-open-final-build.log`。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，最终日志 `/tmp/asky-open-core-tests-final.log`。首次执行有依赖 `AgentRuntime/dist/src/plugin-runner.js` 的插件测试失败；按 README 执行 `npm ci && npm run build` 后重新运行通过。没有修改 Runtime 源码。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --app-opening`：浅色、深色通过，日志 `/tmp/asky-app-opening-final-regression.log`。通过真实窗口的 `sendEvent` 发送 Return，验证普通应用与别名先隐藏、卸载并重置，模拟启动持续等待时仍能重开与输入，旧请求完成不关闭新会话；真实异步服务打开缺失应用返回 Cocoa 错误 260。
- `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --first-presentation`：浅色、深色各重建 10 次通过，日志 `/tmp/asky-open-first-presentation.log`。
- 两种语言的 `Localizable.strings` 均通过 `plutil -lint`；`git diff --check` 通过。

独立系统实验创建三个共享 bundle ID、路径不同的原生测试应用，启动代码先阻塞 2 秒再进入 AppKit 事件循环。在调用方主线程设置 10 ms 计时器，比较原同步 API 与最终构建的 ToolService：

| 调用 | 总等待时间 | 等待期间主线程计时器次数 | 路径验证 |
| --- | --- | --- | --- |
| 原同步 `open(URL)` | 2.085 秒 | 0 | 系统接受请求 |
| 异步启动第一个副本 | 2.243 秒 | 224 | 选中路径的进程正在运行 |
| 已有相同 bundle ID 副本时异步启动第二个路径 | 2.250 秒 | 226 | 第二个选中路径的进程正在运行 |

异步时间包含查询运行进程前额外等待的 150 ms。这不是启动速度基准；实验说明等待目标进程启动时主线程是否仍能处理事件。日志 `/tmp/asky-real-app-launch-probe.log`，本地实验脚本 `/tmp/asky-native-launch-probe.py`，应用及探针位于已忽略的 `build/AppLaunchProbe/`。实验创建的进程已终止。

## 边界

已复现并消除同步启动 API 在慢目标下阻塞调用方主线程的路径，尚未复现用户的钉钉现场，不能宣称所有偶发卡住已经消失。最近回归期间查询未发现 AttributeGraph 循环日志，但没有足够证据把该日志与原卡住建立因果关系。

computer-use 尝试读取正式版窗口时只得到外部显示器的透明拦截窗口及黑色截图，因此未完成正式版中真实鼠标点击或物理键盘验证。原生回归使用进程内 AppKit 键盘事件；系统实验使用独立原生应用。未替换正在运行的正式版，未发布新版本。

README 不变：使用方式、系统要求与已有构建入口未变；新增原生回归参数已同步至双语 `docs/development.md`。AGENTS.md 不变：仍遵循现有 ToolService、窗口资源释放与构建规则，没有新增持久约定。
