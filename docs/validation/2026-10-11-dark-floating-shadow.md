# 暗色浮窗外阴影

## 修复

macOS 26 启动器关闭了 AppKit 窗口阴影，仅依靠 Liquid Glass 自身的光学边缘；剪贴板的系统阴影在暗色下也不明显。为两个浮窗增加独立外形阴影，macOS 26 关闭剪贴板主窗的系统阴影，避免透明画布产生黑框。暗色为黑色 60%，浅色为黑色 18%、半径 40 pt、向下偏移 12 pt。源形状内部通过 destinationOut 挖空，避免给玻璃内部叠加黑底；阴影位于玻璃合成与裁切之外，使用现有 132 pt 透明边距。阴影不接收鼠标事件，不改变窗口尺寸、点击区域。

## 验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- README 声明的 Debug `xcodebuild`：通过。
- 使用固定源码和构建产物副本编译实际 LauncherController / ClipboardController，独立存储、暗色模式、灰色独立背景窗口下，通过 WindowServer 全屏截图检查：两者的外形阴影可见，无透明画布硬黑框；关闭剪贴板后单独检查搜索框。截图为 `build/shadow-fix/composite.png` 和 `search-composite.png`。
- 原 README 启动器回归命令因其他任务在编译期间修改 ClipboardWindow.swift 而中断，未记为通过。
- README 中英文同步更新阴影说明。
- AGENTS.md：没有新增模块、命令或持久规则，保持不变。

本次测试日志及临时原生预览保存在已忽略的 `build/shadow-fix/`。
