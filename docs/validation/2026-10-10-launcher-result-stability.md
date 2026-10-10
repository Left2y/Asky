# 搜索结果更新闪烁与跳动修复

日期：2026-10-10。针对上一轮输入样式修复后仍存在的结果展示跳动。

## 复现与原因

- 对实际 LauncherController、LauncherView 与原生输入编辑器进行窗口回归，不通过桌面辅助功能注入键盘。旧版六行列表逻辑的连续输入采样中，窗口高度从 629 pt 降到 545 pt，输入框屏幕位置出现 42 pt 位移；修复前断言失败。
- 每个字符原先清空所有 Provider 批次，立即发布较短列表，100 ms 后新批次又逐一填回。整块内容上的玻璃效果与原生窗口反复调整，结果区收缩/展开，匹配的行也先消失再出现。
- 即使顶部对齐，NSHostingView 随窗口改变尺寸时仍会出现中间布局。新增“首次异步结果返回”的采样抓到了这一帧；仅推迟 display 或强制 layout 不足以解决。

## 修复

- 将 NSHostingView 放在固定高度的透明画布中，以 AppKit 的弹性底边距保持顶部锚定。窗口按实际内容收缩/展开，SwiftUI 画布本身不跟着反复改变尺寸。合并待执行的 resize，隐藏窗口时取消任务。
- 玻璃材质只施加到背景，文字、原生编辑器和结果内容位于其上；空输入和结果状态使用同一个 32 pt 圆角形状，64 pt 空输入时仍是胶囊。
- 保留仍匹配新查询且来源仍启用的具体结果；新批次按 Provider 替换，空批次会移除旧结果。链接、关键词 URL、AI 提问等依赖查询的动作重新生成，不缓存上一条查询的动作。
- 跟踪当前查询未完成的 Provider 数量，等待期间保留结果区高度。全部批次完成且停止变化 200 ms 后才允许收缩；清空、模式切换和隐藏正常释放结果。没有把旧查询的迟到批次作为新结果接收。
- 为窗口回归提供可注入的搜索源和临时数据根目录，默认 App 初始化及真实搜索源保持原行为。

## 已运行

- `python3 App/Tests/run-launcher-window-regression.py`：通过。使用真实搜索面板和界面树、独立临时数据库、10 ms 应用源与 300 ms 文件源。
- 浅色、深色各采样首次结果返回 70 次、连续原生插入文本 130 次、结果减少及清空 160 次，共 720 次；所有输入框屏幕位置偏差均为 0 pt。执行期间并行的列表八行改动使最终基准窗口高度为 729 pt，连续输入期间最小高度也为 729 pt。
- 验证仍匹配的应用行不会在搜索等待期间消失，慢源尚未完成时不收缩，结果真正变少后收缩，空批次移除旧行，清空恢复 64 pt 输入加阴影画布，关键词切换和正文编辑正常。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression` 与 `build/launcher-input-regression`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：128 tests / 27 suites 通过。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令：成功，BUILD SUCCEEDED。

## 验证范围与维护

窗口测试直接调用原生编辑器的 insertText，并抑制测试面板因用户切换桌面焦点而自动隐藏。覆盖实际渲染树的布局与结果生命周期；没有声称验证物理键盘、真实中文输入法、个人搜索源或逐帧玻璃材质视觉效果。

README 同步了中英文窗口回归命令及测试范围。AGENTS.md 保持不变：现有构建命令、模块与 ToolService 边界未变，新增的专项回归按 README 运行。

测试二进制、日志、复现用源文件与生成的 Xcode 工程沿用现有忽略规则。本次不会提交并行进行的列表行数、滚动条、圆角裁切或其他验收文档改动。
