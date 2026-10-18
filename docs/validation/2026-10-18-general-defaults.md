# 通用设置默认值验证

日期：2026-10-18。

## 行为

- 新安装默认显示菜单栏图标、隐藏 Dock 图标；主题与语言跟随系统，液态玻璃保持开启。
- 正常应用启动时，经 ToolService 向 macOS 注册登录启动；仅在系统状态为未注册时请求注册，保留已启用或等待系统批准的状态。
- 首次初始化成功后持久化标记；后续启动不会重新注册。失败保留重试机会。
- 旧版已保存的配置缺少初始化标记时视为已处理，保留原有登录启动状态及其他设置。
- 通用设置及菜单栏的登录启动读写统一经过 ToolService。

## 实际运行结果

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，262 项 Swift Testing 测试。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --general-defaults`：通过，验证全新默认配置、注册失败传播与重试、单次注册、重启持久化、旧版自定义配置保留。
- `git diff --check`：通过。

登录启动回归使用注入的注册闭包，未改变开发机器的系统登录项；真实 macOS 登录后自动启动仍需已安装应用的登录会话验证。本次没有改动界面布局。

README 中英文已同步；AGENTS.md 检查后保持不变，本次未改变模块、构建命令或持久开发约定。构建及回归产物沿用现有 `build/` 忽略规则。
