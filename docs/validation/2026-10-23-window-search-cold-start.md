# 启动前已全屏的其他 Space 窗口

日期：2026-10-23。

## GitHub 方案依据

- [AltTab 的窗口引用解析](https://github.com/lwouis/alt-tab-macos/blob/master/src/windowserver/WindowElementAcquisition.swift)：将系统窗口 ID 与 AX 引用分开，合并应用发布的窗口及 key/main 窗口，按精确 ID 补查。
- [AltTab 的 WindowServer 接口](https://github.com/lwouis/alt-tab-macos/blob/master/src/macos/api-wrappers/SkyLight.framework.swift)：提供 Space 归属和按窗口 ID 激活的机制。
- [DockDoor 的 AX 封装](https://github.com/ejbills/DockDoor/blob/main/DockDoor/Extensions/AXUIElement.swift)：系统目录存在尚未覆盖的窗口时才补扫，避免仅依赖 AXWindows。
- [Hammerspoon 的窗口过滤器](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/window/window_filter.lua)：明确记录初次实例化时漏掉其他 Space 窗口、之后通过 Space 变化补齐的限制。单纯保留已见窗口不能解决本次冷启动场景。

## 实现与边界

- 所有接口在 ToolService 内。公开 AX 枚举、focused/main 窗口及既有引用为基础；系统窗口目录按 PID／CGWindowID 提供冷启动候选，按时间预算补扫精确引用。扫描预算在应用之间分配，避免前面的应用耗尽后续应用的机会。
- 尚无可解析引用的原生全屏窗口仍可进入结果；用 Space 归属及系统窗口 ID 保留其身份。仅选中后才精确激活，等待相同 ID 的 AXWindow 出现，再执行操作。发现阶段不切换 Space。
- 动态解析未公开的 AX／SkyLight 兼容接口，无静态私有框架依赖；符号缺失时不启用对应补查或物理窗口动作，公开 AX 路径仍可用。不请求新系统权限，不采集窗口像素。
- 按 ID 发送的 key-window 事件只发送 down、没有 up，并指向远离内容的点；本机原生控件回归确认没有激活按钮。不通过标题决定操作目标。
- 系统不提供窗口标题时显示应用名。未覆盖不提供 AXWindow 的应用、全部 macOS 版本、全部第三方控件及全部物理分屏组合；兼容接口变化可能使补充路径退回。

## 实际检查

- `xcodegen generate` 与独立 `build/DerivedData-fullscreen` Debug `xcodebuild`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过；包含兼容符号缺失及扫描预算耗尽的回退检查。
- `ASKY_DERIVED_DATA=/Users/niallyoung/orca/Asky/build/DerivedData-fullscreen python3 App/Tests/run-launcher-window-regression.py --window-search-cold`：通过。
- 冷启动原生回归：测试应用先让两个同标题窗口进入不同原生全屏 Space；检索进程返回桌面，确认两个全屏窗口均不在屏幕上，再执行该进程的第一次 ToolService 窗口查询。首次找到三个同标题窗口（一个普通、两个全屏），查询没有切换 Space。对尚无引用的那一个精确激活、退出全屏、关闭；另一窗口保留，窗口内按钮未触发。本次一次首查观察约 1.3 秒，不作为性能保证。
- `--window-search-spaces`：通过，覆盖已有窗口全屏后的刷新、跨 Space 切换／关闭、关闭后清理及退出应用清理。

测试成功或失败时均清理本次创建的测试子进程，避免残留同名窗口污染后续回归。README 中英文同步冷启动行为和命令；既有 ToolService 边界及指南入口仍适用，AGENTS.md 无需修改。构建及依赖产物沿用已有忽略规则。
