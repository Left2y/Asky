# 指令图标统一与搜索框品牌图标

## 变更

- 设置列表、终端选择器、搜索框指令图标及对应指令结果共用 CommandIcon。
- 外框统一为 24 × 24 pt、6 pt 连续圆角、白色底板及 0.5 pt 轻描边；品牌内容通常为 18 pt，4.5 pt 内圆角。ChatGPT 与原生终端素材自带透明留白，因此通过组件中的光学校正保持视觉大小接近。
- go、chat、yt、dy、tb、jd、bl、gh 的搜索模式显示各自品牌，不再显示默认浏览器图标。终端保留用户选定的应用图标与未安装回退符号。
- 普通书签结果沿用默认浏览器图标，搜索书签入口沿用 Bookmark 图标。
- 原生 launcher 回归 runner 改为编译全部非入口 App 源码并打包 Assets.car，避免缺失 SettingsPage 等依赖或资产。每次重新创建测试可执行文件，避免覆盖运行中的同一 inode。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过。
- `xcodegen generate` 与 README 的 Debug xcodebuild 命令：通过；macOS 构建成功，仍存在先前 Xcode CoreDevice/CoreSimulator 环境诊断。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --command-icons`：通过。两种外观均在真实 NSTextView 中逐一输入八个指令、空格和 SwiftUI，验证指令 token 被消费、搜索内容与原生编辑器同步、对应结果、资产存在、空内容退格退出；另检查终端模式。
- 设置原生回归：通过，输出 `Settings native light/dark snapshots passed`。首次共享产物编译遇到其他任务重建 MCPLink.o；产物稳定后使用独立 UnifiedIconsSettingsRegression.app 输出副本重跑通过。
- 人工检查 `build/command-icons-contact-sheet.png`（浅色/深色九个搜索模式的原生窗口截图汇总）和最新设置截图：品牌图标、底板、圆角与对齐正常。
- 日志：`build/command-icon-build.log`、`build/command-icon-swift-test.log`、`build/command-icon-launcher.log`、`build/command-icon-settings-final.log`。
- README 中英文同步图标规格与回归命令；AGENTS.md unchanged，现有开发和系统调用边界仍适用。
- 临时脚本、截图、测试 App、构建产物继续由已有 build/ 忽略规则覆盖。未打包 Release、未安装。
