# 搜索玻璃背景磨砂增强

## 修改

用户要求保留 70% 不透明度，增强背景模糊，避免收起输入框透出背后文字。

搜索外壳增加独立 `NSVisualEffectView`，使用 `behindWindow` 混合、HUD window 材质及 active 状态。后方窗口先经系统磨砂，再叠加原有 white70 / black70 语义填充与 Clear Liquid Glass。70% token、边框、圆角和阴影保持不变；系统磨砂还会参与最终外观，最终像素并非简单的 70% alpha 合成。

磨砂层裁切至外壳圆角，不接收点击，不模糊输入或结果文字。减少透明度开启时移除磨砂层，继续使用不透明填充与 identity 材质。未使用私有 blur radius API，也不把 Figma Frost 数值解释为原生半径。

公共 API：[Apple behindWindow](https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode-swift.enum/behindwindow)。

## 已运行验证

- 核心包 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：128 项测试、27 suites 通过。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令：BUILD SUCCEEDED。
- `python3 App/Tests/run-launcher-window-regression.py`：最终 HUD 材质版本的浅色/深色检查通过；连续输入、初次结果、收缩及清空的输入框漂移均为 0 pt。
- 独立透明 NSPanel 对比：实际 LauncherView / LauncherController、隔离数据库及模拟结果；浅色结果列表在独立 AppKit 色块和文字背景上确认，背景文字被磨砂打散而前景文字清晰，色块仍有透出。对比截图保存在本地 `build/validation/launcher-frost-light.png`（左侧为之前 Clear-only，右侧为新增 HUD 磨砂）。

- 收起输入框的浅色、深色真实窗口检查：背景 16 pt 文字在输入框内不可辨读，光标与边框保留；截图留在 `build/validation/launcher-frost-empty-light.png` 与 `build/validation/launcher-frost-empty-dark.png`。

临时测试进程已关闭。未切换用户的减少透明度系统设置，也未宣称 Figma 数值逐项等价。未安装或打包发布版本。运行中的产品 App 未重启，新材质需重开新 Debug 构建才生效。

README 中英文同步磨砂层说明。AGENTS.md 未涉及规则或模块变化，保持不变。已有八行列表与滚动裁切的未提交改动保留并从此次提交隔离。测试二进制与截图沿用 `build/` 忽略规则。
