# 单位换算共用汇率双卡片

- 单位换算从普通结果行改为左右双卡片：输入单位和值、目标单位和值，中间双向箭头。
- 单位与汇率共用 `ConversionPairView` 和 `ConversionValueCard`，使用相同尺寸、间距、圆角与数字样式。单位结果按原规则保留最多六位小数；汇率仍保留最多两位小数。
- 单位卡片与汇率一样只读，不提供列表选择、悬停或复制。普通回车不触发隐藏结果的复制；无效输入回到搜索。
- 原生回归脚本补齐 `.app` 与 `Assets.car`，修复直接运行裸二进制时缺少 MingCute 图标的崩溃。

## 已运行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-calculation-regression.py`：通过；真实窗口在 Aqua / Dark Aqua 下覆盖质量、长度、温度、容量，检查无效输入清除卡片、方向键不选择、回车不复制，以及现有计算与汇率流程。
- 人工查看实际窗口截图：浅色、深色单位卡片及深色汇率卡片的左右尺寸、箭头、留白与数字对齐一致。
- 首次原生运行因旧脚本缺少图标资源失败；补齐资源后重跑。温度浮点结果使用 1e-6 容差检查。

本地截图：[浅色单位](../../build/unit-2.0-NSAppearanceNameAqua.png)、[深色单位](../../build/unit-2.0-NSAppearanceNameDarkAqua.png)、[深色汇率](../../build/currency-NSAppearanceNameDarkAqua.png)。

## 文档检查

README 中英文同步卡片布局及只读行为。AGENTS.md 保持不变：没有改变工程边界、命令或持久开发规则。截图、回归程序与构建产物沿用 `.gitignore` 的 `build/` 规则，不添加新忽略项。
