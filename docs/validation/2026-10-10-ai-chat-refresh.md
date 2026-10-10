# 新 AI 对话样式验证

日期：2026-10-10。

## 来源与实现

读取用户提供的 Figma UI 页 22:293，通过 metadata 定位新聊天 43:1071、对话 42:760、历史 38:653，分别获取高保真设计上下文和截图。

- 720 × 640 pt、32 pt 圆角、70% 语义底色；外壳沿用搜索相同的 `.glassEffect(.regular, in:)`。减少透明度分支保留不透明语义背景。
- 顶部两组 32 pt 圆形按钮，历史 / 新对话与置顶 / 关闭；默认普通窗口层级，用户切换置顶后使用 floating，取消恢复 normal。
- 新聊天中央 24/500 问候，历史行高 48 pt，14 pt 标题与实际更新时间。正文和工具行 14 pt，Markdown 标题 16 pt Medium。
- 输入区上 16 / 下 12 pt、44 pt 最小文字区域、12 pt 间距与 32 pt 按钮，默认总高 116 pt；附件卡片高 52 pt，保留缩略图、文件大小及删除操作。
- 使用 Figma 原始 16 × 16 copy SVG，下载到 ChatCopy.imageset，以模板颜色渲染。用户消息悬停或键盘聚焦显示复制，完成回复显示复制；剪贴板写入经 ToolService 的 MessageClipboard。
- Figma 桌面壁纸和示例上传图片不作为静态 App 内容；实际附件仍由用户提供。示例 Work for 13s 未硬编码：当前消息模型没有真实耗时数据。

## 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：130 tests / 27 suites 通过。
- `xcodegen generate` 成功；最终 Swift 源码的 Debug `xcodebuild` 成功。已有 Simulator 版本警告不影响 macOS 构建。
- 编译真实 AgentView、ComposerTextEditor、ComposerAttachmentCard、ChatMarkdownView 的独立原生预览，使用内存示例模型，不读取 Key、不调用模型、不写会话库。
- 原生窗口树确认 720 × 640 pt，点击顶部新对话显示空状态，点击历史显示标题与日期。搜索框实际聚焦输入“日程”后，仅保留匹配行。
- 实际 AgentWindowController 预览中，置顶按钮状态从未置顶到已置顶，窗口 layer 从 0 变为 3。
- 桌面合成截图检查浅色与深色 Regular 玻璃；使用独立彩色背景窗口确认透色，不用缺少背景合成的单窗口截图判断玻璃。原始复制资源已成功通过 Xcode asset catalog 编译，实际预览显示 16 pt 图标。
- `git diff --check` 通过。README 中英文同步界面与手动置顶说明；设计系统同步新节点、字号、输入几何。AGENTS.md 无需更新，现有模块边界与命令仍适用。

预览、日志与截图在忽略的 `build/ai-new-design-preview/`；复用现有 `build/` 忽略规则，无新增规则。测试预览结束后退出。

## 边界

未安装或替换实际运行的 App，未发真实模型请求、执行系统工具、导入真实附件或删除会话。复制写入不以用户剪贴板做回归。减少透明度分支保留现有逻辑，本轮未重新切换系统设置验收。完整 VoiceOver、多屏、长会话和附件导入仍需实际 App 验收。系统玻璃映射不声称与 Figma 光学参数逐项一致。
