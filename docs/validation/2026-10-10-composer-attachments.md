# 输入框附件与图片粘贴

日期：2026-10-10。

## 实现范围

- 使用原生 NSTextView 接收 `⌘V`；Finder 文件优先识别，PNG / TIFF 图片作为附件导入，普通文字保留原生粘贴与撤销。
- 附件横向滚动；图片显示 88 × 88 pt 的 1:1 裁剪缩略图，文件卡片显示原始名称和大小。使用现有 Theme 语义颜色，悬停或键盘聚焦删除按钮时显示删除控件。
- 新增导入、缩略图及草稿文件删除通过 KulaCore 的 ToolService 模块执行。原文件保留，缩略图最大边 200 px；粘贴 TIFF 转 PNG，避免将 TIFF MIME 直接发送到模型。
- Return 发送，Shift Return 换行；输入法正在组字时交给原生输入。只有附件也可提交，以“请分析这些附件”作为请求文字。
- 文本类型文件传入 Runtime 文本附件路径；其他二进制文件保留文件引用，未新增 PDF、Office 等解析能力。图像理解依赖模型支持，Runtime 现有图像上限为 20 MiB。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：119 tests / 24 suites 通过。新增两项测试覆盖名称与内容保留、删除不影响原文件及附件目录外文件、TIFF 转 PNG、缩略图尺寸上限。
- `xcodegen generate`：成功生成工程。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `git diff --check`：通过。

## 未执行

未启动或替换正在运行的 App，未执行真实窗口中的图片 / Finder 文件粘贴、文件选择、拖入、横向滚动、悬停删除、键盘焦点、输入法、明暗主题或减少透明度现场验收。未验证真实模型的图像回答。构建通过不能代替这些交互验证。

## 文档与产物

README 中英文同步新增附件使用方式与解析限制。AGENTS.md: unchanged，命令和模块边界保持原有规则。生成工程、构建输出与 SwiftPM 缓存复用现有 ignore 规则；未改动预先存在的 `docs/validation/acceptance-v1.md`。
