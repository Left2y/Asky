# 基础运算与分组括号验证

日期：2026-10-12

## 用户问题与修复范围

截图输入 `【 (12-12) +1】*12` 回退到询问 AI，因为解析器只支持圆括号。用户要求覆盖日常基础运算，本次支持方括号/花括号与中文 `【】`、`〔〕`（含全角形式），严格检查对应闭合符号。

同时支持科学计数法、隐式乘法（`2(3+4)`、`(2+3)4`）、平方根（`√`、`sqrt(...)`）及末尾百分号。修正负号与乘方优先级，`-2^2 = -4`、`(-2)^2 = 4`、`2^-3 = 0.125`；乘方继续右结合。解析保留空白边界，不再将 `2 3+4` 错误合并成 `23+4`。单次输入限制 4096 字符，分组、负号和乘方递归有界。

百分号规则：末尾 `%` 除以 100（`100*20% = 20`），操作数之间 `%` 继续取余（`10%3 = 1`）；百分比在加减中作为普通数值计算，不采用实体计算器的金额增减模式。除零、负数平方根、不完整/不匹配括号和代码输入不产生计算结果。微积分不在范围内。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过。覆盖原截图、嵌套与全角分组、小数/负数、乘方优先级、科学计数法、根号、百分比、取余、无效输入及递归限制。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-launcher-calculation-regression.py`：浅色/深色均通过，检查原公式、结果、输入补全及复制动作；原有计算器和汇率回归也通过。
- 重启新构建的 `build/DerivedData/Build/Products/Debug/Asky.app`（PID 65646），通过原生 UI 输入 `【 (12-12) +1】*12`。AX 回读与实际窗口截图都显示 `12`。真实按 Return 后，剪贴板回读严格等于 `12`；随后重新输入算式供查看。

视图缓存回归截图不能用于判断玻璃合成，最终视觉验收使用实际 App 窗口。

## 文档与产物

README: updated，中英文同步基础运算及百分号语义。
AGENTS.md: unchanged，架构边界、模块与开发命令未改变。
回归截图与二进制位于 `build/`，使用现有忽略规则，无新增规则。
