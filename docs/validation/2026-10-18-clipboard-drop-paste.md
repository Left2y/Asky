# 剪贴板拖放置入兼容验证（2026-10-18）

## 行为

- 原生拖放优先。拒绝拖放后，仅在真实松手且落点可识别为输入框时，通过 ToolService 复制记录、恢复目标焦点并发送普通 Cmd V。
- 飞书文本输入区存在返回 copy 但没有置入文本的情况。拖动过程中读取同一 AXTextArea 的文本，结束后等待 300 ms；仅当目标身份一致、文本可读且未变化时补粘贴。原生已有变化时不补。该核对只用于飞书文本，终端辅助输入框的空 AXValue 不作为内容证据。
- AX 命中的 Chromium 内层内容 group 会归一到外层 text area，避免把内容节点误当成编辑器。
- Orca 的 Terminal input 是光标处的小辅助文本框，以明确标识的终端父区域识别落点，不扩展普通小文本框，也不包含侧栏、工具栏。
- Esc 取消、未观察到真实松手、非输入区域均不补粘贴；不模拟目标鼠标点击。粘贴前再次检查应用焦点及剪贴板版本。
- 图片导出通过 NSURL 原生文件 writer 拖放，以携带系统文件访问授权。原生接收路径不改写系统剪贴板；补粘贴路径会将当前记录写入剪贴板。

## 实际检查

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DragCompatDerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。包括 PNG/NSURL writer 和终端落点几何检查。
- `--drag-paste-target`：独立进程接收端主动拒绝原生拖放，文本最终为一次 DROP；Esc 和按钮落点不改变目标或系统剪贴板。等待源拖拽会话真正结束后才检查结果，避免把回弹动画中的中间态判作通过。
- `--drag`：原生 NSTextView 实际收到文本，未固定面板关闭，系统剪贴板保持原样。
- `--files`：通过，原生多文件拖放接收了整组 URL，并逐个回读文件内容。系统另输出 sandbox_extension_consume 警告，文件内容回读及所有断言仍通过。

本次为避免并行任务覆盖标准 DerivedData，原生回归使用隔离的 `build/DragCompatDerivedData` 实际 App/module 对象和当前 `App/Tests/ClipboardRegression.swift` 链接运行。标准入口仍为 `App/Tests/run-clipboard-regression.py`；新增 `--drag-paste-target` 会创建独立接收进程。构建和回归产物沿用已有 `build/` 忽略规则。

## 真实应用验收

- 飞书 `com.bytedance.macos.feishu`：真实拖放单条 AskyDragProbe，原生返回 copy，读取前后输入区未变后触发补粘贴。程序读取 focused AXValue 包含测试串，随后界面 AX 树再次显示该文本；测试文字已删除，原有图片草稿保留，未发送消息。
- Orca `/Applications/Orca.app`：真实拖放到当前任务的终端区域，原生返回 none，补粘贴 posted。截图明确显示底部草稿只有 AskyDragProbe，随后删除 13 个测试字符并再次截图确认空输入。终端 AXValue 不暴露渲染后的草稿，未将 AXValue=false 记为失败或以 posted 代替视觉证据。未发送消息或执行命令。
- 两次最终测试均记录松手前实际命中的应用 bundle，排除只激活应用但窗口仍被其他应用覆盖的误测。早期误命中其他窗口、仅窗口关闭或仅 posted 的尝试不算验收通过。

真实应用已验证范围为文本拖入。图片 NSURL 导出及文件接收经过自动化检查，本记录不宣称飞书、Orca 的图片/附件实测通过。原生已接受的飞书文本核对依赖其可读 AXValue 及 300 ms 等待，异步插入超过此窗口仍有重复的可能；其他应用已接受的拖放不补粘贴。

## 文档门禁

README 中英文已同步兜底条件与回归入口。AGENTS.md 保持不变：实现沿用现有 App/ToolService 边界，没有新的独立模块或长期开发约束。并行的类型指令和菜单改动不属于本次提交。
