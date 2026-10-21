# 剪贴板颜色预览

- 完整的 `#RGB`、`#RGBA`、`#RRGGBB`、`#RRGGBBAA` 文本使用圆形色块与下方大写完整十六进制色值。卡片、列表详情和卡片悬停预览复用同一组件；列表行显示小圆形色块。
- 仅改变呈现；数据类型仍为文本，复制、粘贴与拖出保留原文。识别前允许首尾空白，不识别句子中的色值、无 `#` 的文本或非法十六进制输入。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过，共 287 项 Swift Testing 测试。
- 原工作区回归编译受并行修改影响：启动器引用的 `ToolService.calculatorHistory` / `saveCalculatorHistory` 尚不在当时的构建产物中。隔离回归使用任务起点 `c3f990a` 的 App 源码，加本次 `ClipboardWindow.swift` 和 `ClipboardRegression.swift`，复用已成功构建的 Debug 依赖。
- 悬停预览的合成 hover 自动触发检查未通过，未计为通过；该预览的实际鼠标触发仍需手动验收。
- 临时源码、回归程序与截图在 `build/color-preview-validation/`，沿用已有 `build/` 忽略规则，不提交生成产物。
- 隔离回归通过：完整色值、简写展开、大小写、透明度格式、首尾空白、非颜色文本与文件类型拒绝；已检查实际原生窗口的浅色/深色列表详情与卡片截图，圆形色块及下方色值均完整显示。

截图：[浅色列表](../../build/color-preview-validation/build/clipboard-color-light-list.png)、[浅色卡片](../../build/color-preview-validation/build/clipboard-color-light-cards.png)、[深色列表](../../build/color-preview-validation/build/clipboard-color-dark-list.png)、[深色卡片](../../build/color-preview-validation/build/clipboard-color-dark-cards.png)。

隔离回归命令：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 build/color-preview-validation/App/Tests/run-clipboard-regression.py --colors`。同一回归入口已在 README 中以正常工作区路径列出。
