# 黑色石墨 Logo 与留白调整

使用用户提供的 `Vector.svg` 轮廓，保存黑色矢量源为 `App/Branding/Mark.svg`。通过内置 imagegen 制作黑色石墨质感主体、细微倒角高光和白色陶瓷圆角底板；根据用户反馈，黑色主体缩小约两成，底板和界面布局尺寸保持原样。导出时采用平滑圆角边界清理生成图的透明边缘。

## 资源与使用位置

- `App/Branding/Logo.png`：1024 px 主图。
- `AppIcon.appiconset`：完整 16/32/128/256/512 pt 的 1x/2x 资源；系统确认弹窗通过 `AppIcon.icns` 自动使用新图标。
- `AskyLogo.imageset`：512 px，新图用于“关于 Asky”和 `DataSourceIcon` 的个人记忆标识。
- `StatusIcon.imageset`：直接从矢量路径渲染 18/36/54 px 的单色透明图，保留 template 模式；运行时仍显示为 14 pt。菜单栏随系统外观着色。
- README 中英文品牌说明和顶部引用同步；无 Swift 代码或系统接口行为变更。

## 实际验证

- `xcodegen generate` 通过。
- README 中的 Debug `xcodebuild` 命令通过。首次启动遇到本地签名与 `Asky.debug.dylib` 的 Team ID 不兼容；用同一命令附加 `ENABLE_DEBUG_DYLIB=NO` 后构建和实际启动通过。这只是本次构建参数，未改变项目签名配置。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：219 tests / 45 suites 通过。
- AppKit 从构建 Bundle 成功加载 `AskyLogo`、`StatusIcon` 和 `AppIcon.icns`，确认菜单栏资源 `isTemplate=true`、18×18 pt。
- 10 个 AppIcon PNG 尺寸与透明四角检查通过。
- 新构建的实际 App 设置窗口：已检查“关于 Asky”56 pt 标识，以及“数据来源”中个人记忆的小图标，确认缩小后的主体和增加的白色留白。
- 窗口定位时存在已安装版本和多个调试实例干扰。最终使用临时 `--test-branding` 启动入口直接打开新构建设置，检查 PID 21921；入口已移除，最终源码无相关修改，并重新构建验证。
- 本地截图与日志保存于被现有 `build/` 规则忽略的 `build/branding/`，包括 `about-final.png`、`sources-final.png`、`swift-test.log` 和 `final-build.log`。
- 首次完成时未发布 Release，也未替换安装版；用户反馈 Dock 仍为旧图标后，按下节完成安装版资源同步。菜单栏明暗实屏与通知弹窗未单独验收。

## 最终 imagegen 提示词

内置工具，编辑 `App/Branding/Logo.png` 的前一版图像：

> Edit this app icon precisely. The user says the black mark is too large and there is too little whitespace inside the white tile. Keep the white rounded-square ceramic tile EXACTLY the same size, shape, position and finish, and keep all outer transparent canvas margins unchanged. Shrink ONLY the black graphite circular logo mark to 76% of its current width and height, centered on the tile. This adds generous equal white breathing room inside the tile. Preserve the black logo's exact shape, flowing cutout, orientation, subtle texture, black color and delicate bevel shading. No new symbols, no text. Tile stays 82% of canvas width, black mark should now be about 49% of canvas width, with about 16% of canvas width of white padding on each side inside tile. Clean smooth rounded square boundary, transparent corners and outside, absolutely no noisy fringe or scattered white pixels. Front view, no perspective.

## 文档门禁

README: updated — 中英文同步品牌资源说明。

AGENTS.md: unchanged — 架构、构建入口和模块边界未变化。

## 安装版资源同步

- 实际旧图标来自运行中的 `/Applications/Asky.app`，版本 0.0.20（20），首次处理仅更新源码和 Debug 资源。
- 原安装版完整备份到 `build/branding/Installed-Asky-before-logo.app`；只替换安装版 `AppIcon.icns` 和 `Assets.car`，保留原程序版本与业务代码。
- 使用与原包一致的 Asky Local Signing 证书重新签名，保留 identifier、entitlements、requirements、flags 和 runtime 元数据；`codesign --verify --deep --strict` 通过，指定要求中的证书 SHA-1 保持一致。
- 安装版的两份资源 SHA-256 与最终构建资源逐一相同；AppKit 成功加载安装版品牌资源。
- 重新启动实际安装版 PID 55394，检查“关于 Asky”显示黑色 logo 与 0.0.20（20）；实拍保存为 `build/branding/installed-about.png`。
- 重新注册安装包并重启 Dock 以刷新缓存；通过 `NSWorkspace.icon(forFile:)` 读取系统提供的安装版图标并检查为黑色新图，保存 `build/branding/installed-system-icon.png`。Dock 的直接 AX 截图被系统拒绝，未将该缓存读回当作 Dock 实屏截图。
- 本地安装版补丁已完成，GitHub 发布资源仍未更新。

本次跟进 README: unchanged（品牌说明已同步）；AGENTS.md: unchanged（没有开发流程或架构变化）。备份、截图与临时脚本均沿用现有 `build/` 忽略规则。
