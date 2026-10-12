# 计算器括号与 Unicode 运算符验证

日期：2026-10-12

## 修复

原解析器支持括号、嵌套及优先级，但 Unicode 减号/长短横线和中文全角符号会使算式回退到搜索。解析前进行全角宽度转换，并将 `−`、`–`、`—` 归一为 ASCII 减号；显示与复制仍沿用原算式和计算结果。

## 实际执行

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。覆盖 `(12-1)*3`、`(12–1)*3`、`(12−1)×3`、`（１２－１）＊３`、嵌套和优先级，亦检查未闭合括号、除零和代码输入的拒绝行为。
- `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令：通过。
- `python3 App/Tests/run-launcher-calculation-regression.py`：浅色/深色均通过，检查原算式、结果 `33`、补全 `= 33` 与复制动作。
- 重启 `build/DerivedData/Build/Products/Debug/Asky.app`，实际进程 PID 54072。通过原生 UI 输入 `(12–1)*3`；AX 回读 `(12–1)*3 = 33`，实际窗口截图确认输入框补全与计算卡片均显示 `33`。

原生回归使用视图缓存生成的截图不能完整显示玻璃合成；最终视觉确认使用实际运行 App 的窗口截图。构建/验证期间有独立汇率任务并行修改工作区，本任务提交仅包含计算器相关改动。

## 文档检查

README 中英文同步说明括号及兼容符号。AGENTS.md 的工具边界和验证入口保持有效，无需修改。`build/` 产物复用现有忽略规则。
