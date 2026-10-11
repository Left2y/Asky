# 汇率结果精简与选中状态

- 成功换算只保留旗帜、数值与币种，移除第二行单价、ECB、日期、缓存及复制说明。不可用原因仍保留。
- 恢复汇率行的选中背景、悬停反馈和辅助功能选中标记；上下键选择与回车复制沿用现有逻辑。
- README 中英文说明同步。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-launcher-calculation-regression.py`：最终通过。测试启动真实 LauncherPanel，验证空 subtitle、复制 action、上下选择以及浅色／深色窗口截图。检查了 `build/currency-selected-NSAppearanceNameAqua.png` 和 `build/currency-selected-NSAppearanceNameDarkAqua.png`，第二项选中背景清晰，说明文字已移除。
- 早期测试受活动输入框残留文本干扰；测试同步 field editor 和 model 后通过。一次编译因其他进程修改 LauncherView.swift 中断，重跑通过。
- 截图是原生测试窗口的内容截图，不是安装版本或桌面透明合成验收。本次未打包或安装。

## 完成检查

- README: updated，中英文同步精简结果与选择复制说明。
- AGENTS.md: unchanged，未改变架构边界或开发命令。
- 构建产物和截图沿用现有 `.gitignore` 的 `build/` 规则。
- 未提交：LauncherModel、README 和现有未跟踪原生测试文件与本次之前的汇率实现交叠，无法形成独立完整提交，保留现有工作区和索引。
