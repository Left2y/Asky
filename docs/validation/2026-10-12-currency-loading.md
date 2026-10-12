# 汇率首次加载优化验证

日期：2026-10-12。

- 应用启动通过 ToolService 后台预取 ECB 汇率，不阻塞启动。
- 已有缓存立即计算；超过六小时的缓存同时触发后台刷新。启动预取与无缓存查询共用一个进行中的请求，成功后保存到磁盘。
- 删除汇率输入后的固定 150 ms 等待；只有请求超过 200 ms 才显示加载提示。取消或切换输入会取消旧提示，避免旧查询覆盖新查询。
- 无缓存且预取未完成时仍需等待真实网络；没有内置或编造汇率。本次未测量真实 ECB 网络冷启动延迟。

实际执行：

1. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过，包括新增的阻塞网络下旧缓存立即返回、预取与查询共用请求、缓存跨实例离线读取检查。
2. `xcodegen generate`：通过。
3. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
4. `python3 App/Tests/run-launcher-calculation-regression.py`：新编译的实际 Launcher 原生窗口在 Aqua / DarkAqua 下通过缓存加载无提示闪烁、等待期间回车不提交 AI、换算、反向换算、取消与显式币种对检查。截图保存在被忽略的 `build/` 下；截图采用视图缓存，不能作为完整窗口玻璃合成验收。

验证时存在并行的括号计算器修改；本次提交隔离汇率实现、两条原生加载提示断言及 README 汇率说明，不包含并行计算器改动。未打包、安装或推送。

README 中英文已同步预取与后台刷新行为；AGENTS.md 的模块边界和开发规则没有变化。
