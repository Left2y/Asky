# 快捷键设置同步

设置页此前只列出早期 5 项可配置快捷键。现按全局、文件与应用、启动器、剪贴板历史、AI 对话分组，补充已有固定快捷键及生效条件，保留原有录制与恢复默认行为。

实际执行：

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过；补齐翻译后再次构建通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：298 项 Swift Testing 测试通过。
- `python3 App/Tests/check-localization.py`：通过。
- 设置原生回归 `--hotkeys-only`：英文及 `-AppleLanguages '(zh-Hans)'` 中文运行均通过浅色、深色窗口快照和滚动到底检查。
- `git diff --check`：通过。

首次原生回归因并行构建修改共享 `Resources.o` 失败。将 DerivedData 克隆至忽略目录 `build/HotkeyDerivedData`，并使用独立的 `build/HotkeysSettingsRegression.app` 重跑通过。最后的本地化资源更新后重新签名该回归应用并再次运行通过。

快照位于 `build/settings-{light,dark}-hotkey{,-scrolled}.png`，英文副本位于 `build/hotkeys-en/`。人工检查窗口中的分组、按键列、脚注及末尾 AI 对话区域。此次验证覆盖设置展示与滚动，没有重新执行每项系统快捷键的实际操作。

README: updated，中英文同步设置页范围及原生回归命令。AGENTS.md: unchanged，未改变架构边界、项目约定或现有开发流程。
