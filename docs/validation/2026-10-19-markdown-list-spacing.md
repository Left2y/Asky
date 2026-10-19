# Markdown 列表换行间距

日期：2026-10-19。

## 修复

`ChatMarkdownView` 的正文使用 28 pt 段落行高，但 MarkdownUI 2.4.1 的紧凑列表会忽略前一块的 bottom margin。只有正文的 14 pt bottom margin 时，列表项之间没有段落留白，换行间距反而大于相邻列表项间距。

在共享 `listItem` 样式中设置 top / bottom margin 为 14 pt。有序、无序、嵌套列表均使用该样式；MarkdownUI 取相邻 margin 的最大值，带空行的列表不会叠加成 28 pt。首项不额外添加内部顶部 padding。正文行高、缩进、编号和圆点保持现有渲染。

## 已执行检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：286 项测试通过。
- `xcodegen generate`：成功。
- README 声明的 Debug `xcodebuild`（`build/DerivedData`）：`BUILD SUCCEEDED`。
- 编译当前 App 实际源文件并启动原生 `NSHostingView` 预览，检查浅色／深色的长文本无序列表、有序列表和嵌套列表；换行行距保持原样，相邻项目有独立留白。预览截图见 `build/ListSpacingPreview/after.png`。窗口截图上下边缘有裁切，未将边缘外的内容计为视觉验收。
- 预览编译首次因默认 SDK 26.5 与 Debug 产物 SDK 27.0 不一致失败；显式指定 Xcode 的 MacOSX SDK 后编译运行成功。预览不调用模型或写入真实会话。
- `git diff --check`：通过。

README: unchanged；仅修复现有渲染间距，使用方式和开发命令不变。
AGENTS.md: unchanged；现有模块边界和指令继续适用。
