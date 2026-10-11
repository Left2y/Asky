# macOS 背景材质兼容

## 实现

- App、MCP 工具与 KulaCore 的最低运行目标统一降为 macOS 15。现有 Synchronization.Mutex 需要 macOS 15，未声明 macOS 14 支持。已发布的 0.0.6 安装包仍保持原有 macOS 26 要求，本次未打包或发布。
- macOS 26+ 保留原生 Regular Liquid Glass；旧版本使用 NSVisualEffectView 的 underWindowBackground / behindWindow / active，叠加 background 变量（浅色白 60%、深色黑 60%）和 1pt border 描边。原生模糊半径由系统控制，用户已接受此方式。
- 设置侧栏和内容区按版本适配；旧版背景延伸至标题栏，滚动内容仍位于工具栏下方。授权和确认按钮按版本切换 glass / bordered 样式。降低透明度或增强对比度继续使用不透明表面。
- 为兼容旧系统，进程工作目录使用旧版 posix_spawn_file_actions_addchdir_np；地图地址解析使用 MKLocalSearch。macOS 26+ 保持原调用。
- Debug 专用 --preview-legacy-material 参数可在新系统检查旧版材质，Release 不提供这个覆盖。

## 检查

- DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test（Packages/KulaCore）：通过；其中真实 Node 不可达模型退出检查通过，已有在线 GitHub 插件测试按配置跳过。
- xcodegen generate：通过。
- README 中的 Debug xcodebuild 命令：通过，构建包的 LSMinimumSystemVersion 为 15.0。
- 设置回归正常分支：通过，含浅深色页面、工具栏安全区、授权生命周期和拖拽恢复检查。

- python3 App/Tests/run-settings-regression.py --preview-legacy-material：最终修改后通过，覆盖浅深色设置页面、工具栏安全区、授权生命周期和拖拽恢复。
- 使用 computer-use 检查新编译的 SettingsRegression 原生窗口：旧版材质背景延伸到标题栏，描边与内容布局正常；仅检查预览分支，不视为 macOS 15 实机验证。
- git diff --check：通过。构建、快照与测试产物由已有 build/ 和 Packages/KulaCore/.build/ 忽略规则覆盖，无新增忽略规则。

## 限制

验证主机运行 macOS 27.0.1。低版本目标编译与旧版材质预览不能代替 macOS 15 实机验收；旧系统下的地图查询、Agent 进程工作目录和辅助功能视觉行为仍需实机检查。未承诺精确 120px 模糊半径。
