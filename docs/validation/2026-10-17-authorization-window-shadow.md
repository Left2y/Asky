# 拖拽授权弹窗黑框修复

日期：2026-10-17。

## 原因与改动

`PermissionAuthorizationWindow` 仍将带有外侧 20 点透明留白的 SwiftUI 玻璃直接放入开启系统阴影的窗口，遗漏了搜索窗口已经采用的 Spotlight 式表面结构。

- 删除玻璃外的透明留白，保留内容内边距；窗口宽度由 400 恢复为实际玻璃宽度 360 点。
- 使用 `WindowSurface.glassContentView`，玻璃与内容同按 24 点圆角裁剪；SwiftUI 仅提供兼容性回退背景。
- 内容高度变化时从 hosting view 测量，继续适配准备、重试和重新启动状态。
- 原生窗口 appearance 与传入的 SwiftUI color scheme 一致，避免浅色文字样式落在深色玻璃上。

## 验证

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令（追加 `-skipPackageUpdates`）：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，37 个 Swift Testing 测试。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py`：通过。检查实际弹窗的 360 点宽度、原生玻璃、圆角裁剪、深浅色一致性，以及授权完成、重新授权、准备中取消和关闭生命周期。

实际查看浅色与深色窗口截图：玻璃外无方角黑边，阴影沿圆角外形，文字与玻璃外观一致。

截图路径：`build/authorization-light.png`、`build/authorization-light-regrant.png`、`build/authorization-dark.png`（build 目录沿用现有忽略规则）。本次使用注入状态模拟授权，不重置真实 TCC 权限；未替换已安装应用，未验证 macOS 15 实机回退。
