# 亮色设置卡片对比度

## 修改

- 所有 `SettingsForm` 卡片的亮色白色填充从 70% 调整为 18%，保留底层玻璃与背景颜色。
- 共享行分隔线在亮色模式下从 8% 黑色减至 4%；暗色卡片和分隔线不变。
- 输入框、按钮及文字颜色不变。排除列表内部原生 `Divider` 不在本次修改范围。

## 实际验证

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：36 个测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py`：全部设置页亮暗快照、窗口布局、授权生命周期与卡片拖放恢复通过。
- 人工查看 `build/settings-light-sources-scrolled.png` 和暗色对应快照：亮色卡片填充与分隔线明显减淡，暗色样式保持原有层次。
- 实际可见 `SettingsRegression.app`（共享生产 `SettingsWindow` 和页面代码）通过 Orca 截图检查；当前系统为暗色。

## 运行边界

共享 `build/DerivedData` 的 Debug 应用首次启动遇到主程序与动态库签名不一致。另以 `build/LightCellDerivedData` 和 `ENABLE_DEBUG_DYLIB=NO` 构建成功，启动后通过 PID 与可执行路径确认，剪贴板窗口可见。该独立应用的设置快捷键检查未取得可见窗口，因此不把它记为主应用亮色窗口验收；亮暗设置检查来自新编译的原生回归窗口。

## 文档与产物

README: unchanged — 仅调整设置视觉强度，不改变功能、使用方法或开发命令。

AGENTS.md: unchanged — 未引入新的模块边界、工具或持久开发规则。

日志、回归程序、截图与独立构建均使用现有 `build/` 忽略规则；不提交已有其他任务改动。
