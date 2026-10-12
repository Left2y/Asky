# 设置页面模板与玻璃层次

参考：[Figma 61:164](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=61-164)。

## 实现

- 各设置页共用 `SettingsForm`：220pt 单色侧栏、16pt 中等字重页标题、14pt 正文、12pt 分组圆角；通用页合并主题与语言。
- 整窗使用独立背景容器和 AppKit Regular 玻璃，移除侧栏的独立材质；外圆角 32pt，初始尺寸 900 × 800。
- 聚焦 / 失焦分别使用 25% / 55% 明暗背景染色和 6% / 3% 中性色层。降低透明度 / 增强对比度使用不透明语义背景。
- 浅色卡片使用 70% 白色，暗色卡片使用 6% 白色提亮，降低暗色卡片与背景之间的明暗差。
- 原生 NSButton 与 NSPopUpButton 保留系统控件行为；添加文件夹按钮使用较大的原生控件尺寸。普通输入和密码输入使用低对比背景及聚焦描边，避免暗色默认黑色填充。
- Figma 的 12 个侧栏 SVG 原样保留，并转换为 16 × 16pt PDF 供 Asset Catalog 使用；图标按模板位置显示。

## 实际执行的验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：223 个 Swift Testing 测试通过。
- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令，使用独立 `build/SettingsStyleDerivedData`：通过。
- 设置回归：全页浅色 / 深色快照、长内容滚动与工具栏边界、授权窗口生命周期及授权卡片取消拖拽恢复通过。
- 最后一次回归在修复测试包签名后运行：`codesign --force --sign - build/SettingsRegression.app`，再运行该包的可执行文件；输出 `Settings native snapshots, authorization lifecycle and card drag restoration passed`。回归脚本已自动刷新签名，与剪贴板回归保持一致，避免替换可执行文件 / 资源后被系统终止。
- 用新构建的 `SettingsRegression.app --preview --dark` 检查实际窗口（PID 99005）：暗色卡片层次、普通 / 聚焦输入框及添加文件夹按钮已检查。它与主应用使用同一个 `SettingsWindow.make`，但使用独立临时数据。
- 主应用曾使用独立 Debug 构建运行并打开设置。后续捕获遇到主进程 AX 读取失败，最终输入框检查使用上述新构建的原生回归窗口；不能将此记录视为系统授权或主应用真实账户操作的验收。

窗口截图对独立玻璃窗口的后方取样与桌面合成可能不同；未声称逐项复制 Figma 的光学渲染参数。构建日志、回归截图及本次脏工作区基线均在已忽略的 `build/` 下，未打包或发布。

## 文档与隔离

README 已同步中英文设置布局与语言位置；AGENTS.md 无新的持久规则变化。任务提交只选择样式、静态资源、回归基础设施与本记录；保留原有提醒、信息读取、系统权限和数据文档等改动。
