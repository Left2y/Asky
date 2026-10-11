# 剪贴板原生玻璃颜色

搜索框、固定按钮和历史卡片移除 `kBackground` 填充，使用共享 `NativeGlassBackground` 的无染色 Regular 材质。固定按钮和卡片使用 interactive 变体；未选中卡片使用原生边缘，选中卡片保留 2 pt 描边。尺寸、搜索和卡片操作未改动。

## 已执行验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- 使用 SDKROOT 指向 Xcode 的 MacOSX27.0.sdk 运行现有 `run-clipboard-regression.py --preview`：成功启动真实 NSPanel；通过 Orca computer-use 捕获并检查深色窗口，搜索框、按钮和卡片呈原生灰色层级，文字和选中边缘可辨识。预览使用临时数据，不写入用户剪贴板历史。
- 完整 `run-clipboard-regression.py`：未通过，停在 `ClipboardRegression.swift:73` 的四条记录数量断言；未到达后续浅色/深色快照和行为验证。本次未修改记录逻辑或该回归断言。
- `git diff --check`：通过。

预览脚本首次未指定 SDKROOT 时，默认 swiftc SDK 26.5 与构建产物 SDK 27.0 不一致；明确使用构建 SDK 后成功。此次未验证浅色和不同桌面背景，也未将视图缓存快照当作背景合成验收。

## 文档与提交范围

设计系统同步剪贴板控件的材质例外。README 保持不变：现有原生玻璃及辅助功能说明仍然适用；AGENTS.md 保持不变：没有开发命令或架构边界变化。

工作区在本次开始前已有同文件的玻璃改造，并依赖尚未提交的 `NativeGlassBackground.swift`。为避免混入已有改动，本次保留未提交状态。
