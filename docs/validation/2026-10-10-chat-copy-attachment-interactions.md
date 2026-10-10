# 对话复制与附件交互修复

日期：2026-10-10。

## 实现依据

- 读取用户指定的 Figma UI 页 `22:293` 的 metadata 和截图，再读取用户气泡 `43:997`、输入框 `43:931`、回复内容 `43:1052` 的高保真上下文与截图。
- 复用本地 `ChatCopy` 原始 SVG：16 pt 图标、6 pt 内边距、28 pt 点击区域与 8 pt 圆角。用户和回复复制按钮统一使用 `ThemeColor.kInteractionHover`；其实际 token 为 `interactionHover`，Light 为 black6、Dark 为 white8。
- 附件按钮保持 32 pt 圆形，使用同一悬停 token，点击直接打开系统多选文件选择器。移除附件菜单，设置仍可通过 `⌘,` 或标题右键菜单打开。
- 用户气泡的完整矩形包含 8 pt 空隙与整行复制区域，复制按钮另保留独立 hover 状态；气泡、空隙和按钮之间的指针移动不会因子视图切换而撤销显示条件。保留键盘聚焦显示。
- 保留既有 ComposerTextEditor 的原生文本粘贴、撤销和 ToolService 文件／PNG／TIFF 导入通路。

## 实际执行的检查

- `xcodegen generate`：成功。
- 最终源码执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：133 tests / 27 suites，1 issue；工作区已有的 `LinksTests.bareWordGuessesDotComSite` 期待 `https://www.kimi.com`，但当前 LinksProvider 返回空。本任务未修改该实现或测试，不能将核心测试记为全部通过。
- 编译真实 AgentView、ComposerTextEditor、ComposerAttachmentCard、ChatMarkdownView 的独立原生预览；使用内存示例模型，附件方法来自当前 AgentModel，导入经真实 ToolService，仅写忽略的测试目录。
- 通过 computer-use 实际点击附件按钮：直接出现 macOS Open sheet，无中间菜单。选择测试 `sample.txt` 后回读到 `sample.txt / 18 bytes` 卡片。
- 文本粘贴回读到“粘贴文本验证”；最终源码预览中图片 `⌘V` 回读到“粘贴图片.png”卡片；文件 URL `⌘V` 回读到 `sample.txt / 18 bytes` 卡片。测试后恢复原剪贴板。
- `git diff --check`：通过。README 中英文同步直接附件选择、粘贴和设置入口；AGENTS.md 无新增命令或边界，保持不变。

## 验证边界与产物

自动化工具的坐标点击未可靠触发普通 hover，用户复制按钮在截图中仍未显示，因此本轮不把鼠标悬停轨迹、悬停颜色或复制回读记作通过。这些部分已有源码修复与构建检查，仍需实际指针移动验收。未向模型发送测试消息，未执行系统工具；未安装或打包 Release，未验证深色与减少透明度。

预览、Figma 页截图、测试附件和日志在 `build/chat-interactions/`，复用现有 `build/` 忽略规则。原有搜索、书签、图标、PRD、project.yml 与 README 的其他修改不属于本任务。
