# Icon Composer 分层图标与白框修正

## 问题与修改

前次只交付传统 PNG／ICNS，未验证 Dock。用户实屏出现外层厚白框与缩小的主视觉，随后指出应该使用 Icon Composer；前次验证不能视为 Dock 验收。

- `App/Branding/AskyNative.icon` 为正式原生源文件：独立深蓝纯色背景填充与透明小伙伴前景，不把已带圆角和留白的整张图再次放进系统图标容器。
- 文档先在 Xcode 附带的 Icon Composer 中新建、导入透明前景并保存；随后配置独立纯色背景、关闭分组高光和投影，使用同一工具附带的 `ictool` 渲染，并在 Icon Composer 重新打开检查最终文件。
- 前景通过内置 imagegen 从已认可的图像提取：只移除背景，保持无触角造型、歪头、表情与浅蓝磨砂；要求身体自然延伸至底边。去掉低 alpha 背景残留后归一至 1024 px，不将原图的圆角裁切带入前景。
- 前景 `glass=false`，分组 `specular=false`、`shadow.opacity=0`、`translucency.enabled=false`。前景底部不再附加投影，原生渲染未见用户指出的水平接缝。
- `project.yml` 将 `.icon` 交给 Xcode 资源编译，`ASSETCATALOG_COMPILER_APPICON_NAME=AskyNative`。
- 删除打开设置时把旧 `AppIcon` 位图重新指定为 `NSApp.applicationIconImage` 的逻辑，避免覆盖原生分层图标。
- PNG、ICNS、传统 appiconset 与设置页共享图从原生渲染同步导出，作为静态资源；正式应用入口选择 `.icon`。

## 实际验证

- `xcodegen generate` 成功。
- README 的 Debug `xcodebuild` 命令成功，资源编译日志明确包含 `AskyNative.icon` 和 `--app-icon AskyNative`。日志：`build/branding-composer/xcodebuild.log`。
- 构建包的 `CFBundleIconName` 与 `CFBundleIconFile` 均读回 `AskyNative`，存在 `AskyNative.icns` 和编译后的 Assets.car。
- 首次默认 CLT 工具链执行 `swift test` 失败，报 `no such module Testing`；按项目约定使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 重跑成功。日志：`build/branding-composer/swift-test.log`。
- Icon Composer 重新打开正式文件，确认一个透明前景层、独立深蓝 Solid 背景，原生 macOS 预览未见厚白框和底部横向接缝。
- `ictool` 成功导出设计代际 27 的 Default/Dark/Mono 以及代际 26 的 Default。目视检查 Default 与 Dark；渲染文件在 `build/branding-composer/`。
- 使用 `NSWorkspace.icon(forFile:)` 读取新构建应用的系统图标并保存为 `build/branding-composer/system-icon.png`，目视确认没有厚白框，图形比例正常。
- Dock 的直接截图调用超时，不能将系统图标读回等同于 Dock 实屏验收。打开设置后的 Dock 状态也未完成实屏验收。

## 交付范围

README 中英文同步说明正式分层源文件与静态导出的用途。现有构建命令未变，AGENTS.md 无需调整。本次未发布 Release，也未替换 `/Applications` 安装版。其他未提交功能变更保留；探索文档及构建日志复用已有 `build/` 忽略规则。

原生流程参考：[Apple Icon Composer 文档](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)。
