# KulaHere 原生界面与设计系统

更新日期：2026 年 10 月 9 日。状态：已核对设计来源，原生页面与视觉验证尚未实现。

界面使用 SwiftUI 与 AppKit 原生组件，应用用户定义的变量和文字 Styles，并使用系统 Liquid Glass。产品流程以 [PRD](PRD.md) 为准；窗口规格是原型默认值，不表示 Figma 已提供完整界面。

## 设计来源与检查结果

来源：[KulaHere Figma，node 6:12](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/KulaHere?node-id=6-12)。

2026 年 10 月 9 日只读检查：node 6:12 为名为 Button 的 PAGE，子节点为 0。文件级数据有 6 个变量集合、106 个变量、24 个文字 Styles，0 个本地 Paint Styles、0 个本地 Effect Styles。没有可从该目标直接复刻的屏幕、组件几何或玻璃效果规范；页面名 Button 不能视为一个已设计按钮组件。

| 集合 | 数量 | 模式与作用 |
| --- | --- | --- |
| Palette | 32 | Default；基础色及透明度阶梯 |
| Typography | 21 | English / Chinese；字体、字重、字号与两种行高 |
| Border | 3 | Default；0 / 1 / 2 |
| Radius | 10 | Default；0、4、8、12、16、24、32、40、48、99999 |
| Opacity | 1 | Default；disabled = 30 |
| Colors | 39 | Light / Dark；语义颜色与别名 |

后续 Figma 变更先核对来源，再更新附录与原生映射；不要在文件中自动创建组件或改写用户变量。本稿附录为设计数据快照，不是自动生成的生产源码。

## 原生映射规则

| 设计数据 | 原生应用方式 |
| --- | --- |
| Palette / Colors | 统一 Theme 层解析语义角色与当前外观，控件不散落硬编码颜色 |
| Typography | 用文字角色映射 SwiftUI Font / AppKit 字体属性；按内容语言使用 English / Chinese 家族与自然回退 |
| Border | 以设计基准值映射原生 pt，在目标显示 scale 下检查清晰度 |
| Radius | 有限值用于相应内容形状；radius99999 映射 Capsule，不创建巨大的圆角数值 |
| Opacity | disabled 30 是百分比，原生归一化为 0.3；同时设置真实禁用状态 |
| Styles | 保留“字号 / 字重 / Default 或 Paragraph”的来源关系；不要把行高当文字框固定高度 |

语义颜色先递归解析别名，再按模式取得基础值；原生代码名可规范化，但维护明确映射。源名称 backgroundDisbled 保留原拼写，代码可映射到 backgroundDisabled；Overlay 与 Input 的大写同样在来源记录中保留，不偷偷改写 Figma。

行高是设计目标。SwiftUI 的 lineSpacing 不直接等于总行高，应核对字体度量、基线、中英混排与原生控件内部排版；不能为了完全相等的数字裁切文字。字号与行高在正常大小下按源值应用，并保持系统文本放大与辅助功能可用。

当前没有 Spacing 变量集合。首轮沿用原生控件内距与布局习惯；若需要独立空间 token，应作为新的设计决定记录，不能宣称已从 Figma 导出。

## 界面结构与窗口默认值

一个 AppKit NSPanel 承载快捷入口与展开对话，保留键盘操作、焦点和原工作应用的切换体验。SwiftUI 管理内容；确需原生窗口、选区、快捷键或特定控件能力时使用 AppKit 适配。

| 区域 | 原型默认值与行为 |
| --- | --- |
| Launcher | 宽 640 pt，高度随结果变化，最大 540 pt |
| Agent | 初始 760 × 720 pt，最小 640 × 560 pt，可调整大小 |
| 输入 | 18/400/Default |
| 结果主文本 | 14/400/Default |
| 次要说明与快捷键 | 12/400/Default |
| 按钮文字 | 14/500/Default |
| 对话正文 | 16/400/Paragraph |

以上尺寸与角色来自当前实施方案，属于建议默认值。应在多显示器、长文本、辅助功能放大与真实任务中调整，不能把它们归因于空 Figma 页面。

交互区至少覆盖输入、可选择结果、附件预览、工具进度、澄清、确认、实际结果、历史与记忆管理。确认界面显示具体目标和变更；“正在启动 AI”立即反馈，但不是承诺 Pi 已经在某个时限内启动。

## 原生组件使用

| 需求 | 首选原生能力 | 保留的行为 |
| --- | --- | --- |
| 输入、搜索与多行任务 | SwiftUI TextField / TextEditor，必要时 NSTextView 适配 | 选区、输入法、粘贴、键盘与辅助功能 |
| 动作、选择与开关 | Button、Toggle、Picker、Menu | 原生语义、焦点、禁用与快捷键 |
| 结果与历史 | 原生列表或有界分页滚动区域 | 稳定目标标识、键盘选择、按需加载 |
| 进度与状态 | ProgressView 与结构化工具结果 | 停止、拒绝、错误与待核实可区分 |
| 附件与来源 | 原生预览、文件或目标打开入口 | 缩略图、查看原件与可追溯来源 |

Theme、ButtonStyle、LabelStyle 或 ViewModifier 只负责样式映射，不重写控件固有行为。不能把可点击文字当按钮、颜色当唯一状态或失去原生输入法行为。图标初始优先系统 SF Symbols，若后续提供自有图标再记录来源与替换映射。

## Liquid Glass

首版技术默认基于 macOS 26 原生能力。SwiftUI 的 glassEffect、GlassEffectContainer 与原生玻璃按钮样式，以及 AppKit NSGlassEffectView 是实施候选；具体组合与 SDK 可用性在 M0 编译和视觉验证。[Apple SwiftUI Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)、[Apple NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview)

- 浮动入口外壳、导航、工具栏与关键操作适合玻璃；使用系统协调的效果容器，避免各层独立叠加。
- 对话正文、长文本与结果内容保持清晰阅读层，不能把每个卡片都做成玻璃。
- background 等语义变量用于需要的内容与控件角色，不把一层自定义不透明背景覆盖在系统玻璃上。
- 选中、悬停、焦点和禁用需要可辨识；品牌颜色叠加不能破坏系统玻璃的光学表现。
- 不通过截取桌面、持续抓取壁纸或自制大图模糊模拟原生效果。
- 系统减少透明度、提高对比度或减少动态效果时使用系统适配，必要时降低装饰效果并保持文字可读。

## 视觉与辅助功能验收

检查 Light / Dark、浅色和深色壁纸、复杂壁纸、多显示器与不同 scale；核对焦点环、键盘顺序、VoiceOver 标签、禁用状态、文本放大、减少透明度和减少动态效果。

红色、绿色与低透明度角色尤其应检查小文字对比度。不能只凭 token 数值认定可读；状态同时有图标或文案，需要高对比适配时保持语义并记录具体设计处理。

页面隐藏后停止不必要动画，卸载重内容，玻璃视图和图片资源不持续积累。相关验证见 [资源生命周期](resource-lifecycle.md) 与 [实施与验证](implementation-and-validation.md)。

## 设计数据附录

颜色以 8-bit sRGB 十六进制与透明度百分比表示，透明度已按原始浮点值归一显示。别名仍按“集合 / 变量名称”记录，保留 Light / Dark 的关系，不只保存一次解析后的结果。数字是 Figma 设计值；Opacity 百分比、Capsule 与原生排版换算遵循上文规则。

### Palette 变量

| 源名称 | Default |
| --- | --- |
| black100 | #0E0F11 / 100% |
| black90 | #0E0F11 / 90% |
| black80 | #0E0F11 / 80% |
| black70 | #0E0F11 / 70% |
| black60 | #0E0F11 / 60% |
| black50 | #0E0F11 / 50% |
| black40 | #0E0F11 / 40% |
| black30 | #0E0F11 / 30% |
| black20 | #0E0F11 / 20% |
| black10 | #0E0F11 / 10% |
| black8 | #0E0F11 / 8% |
| black6 | #0E0F11 / 6% |
| black4 | #0E0F11 / 4% |
| black2 | #0E0F11 / 2% |
| black0 | #0E0F11 / 0% |
| white100 | #FFFFFF / 100% |
| white90 | #FFFFFF / 90% |
| white80 | #FFFFFF / 80% |
| white70 | #FFFFFF / 70% |
| white60 | #FFFFFF / 60% |
| white50 | #FFFFFF / 50% |
| white40 | #FFFFFF / 40% |
| white30 | #FFFFFF / 30% |
| white20 | #FFFFFF / 20% |
| white10 | #FFFFFF / 10% |
| white8 | #FFFFFF / 8% |
| white6 | #FFFFFF / 6% |
| white4 | #FFFFFF / 4% |
| white2 | #FFFFFF / 2% |
| white0 | #FFFFFF / 0% |
| red | #FF0730 / 100% |
| green | #28EEA5 / 100% |

### Typography 变量

| 源名称 | English | Chinese |
| --- | --- | --- |
| fontFamily | SF Pro | PingFang SC |
| fontWeightRegular | 400 | 400 |
| fontWeightMedium | 500 | 500 |
| fontSize12 | 12 | 12 |
| lineHeight12 | 20 | 20 |
| fontSize14 | 14 | 14 |
| lineHeight14 | 22 | 22 |
| fontSize16 | 16 | 16 |
| lineHeight16 | 24 | 24 |
| fontSize18 | 18 | 18 |
| lineHeight18 | 26 | 26 |
| fontSize20 | 20 | 20 |
| lineHeight20 | 28 | 28 |
| fontSize24 | 24 | 24 |
| lineHeight24 | 32 | 32 |
| lineHeightParagraph12 | 24 | 24 |
| lineHeightParagraph14 | 28 | 28 |
| lineHeightParagraph16 | 32 | 32 |
| lineHeightParagraph18 | 36 | 36 |
| lineHeightParagraph20 | 40 | 40 |
| lineHeightParagraph24 | 48 | 48 |

### Border 变量

| 源名称 | Default |
| --- | --- |
| borderWidth0 | 0 |
| borderWidth1 | 1 |
| borderWidth2 | 2 |

### Radius 变量

| 源名称 | Default |
| --- | --- |
| radius0 | 0 |
| radius4 | 4 |
| radius8 | 8 |
| radius12 | 12 |
| radius16 | 16 |
| radius24 | 24 |
| radius32 | 32 |
| radius40 | 40 |
| radius48 | 48 |
| radius99999 | 99999 |

### Opacity 变量

| 源名称 | Default |
| --- | --- |
| disabled | 30 |

### Colors 变量

| 源名称 | Light | Dark |
| --- | --- | --- |
| text | Palette/black90 | Palette/white90 |
| textSubtle | Palette/black70 | Palette/white70 |
| textSubtlest | Palette/black50 | Palette/white50 |
| textDisabled | Palette/black30 | Palette/white30 |
| textInverted | Palette/white100 | Palette/black100 |
| textPrimary | Palette/black90 | Palette/white90 |
| textNegative | Palette/red | Palette/red |
| textPositive | Palette/green | Palette/green |
| textSelected | Colors/textPrimary | Colors/textPrimary |
| icon | Palette/black80 | Palette/white80 |
| iconSubtle | Palette/black60 | Palette/white60 |
| iconSubtlest | Palette/black50 | Palette/white50 |
| iconDisabled | Palette/black30 | Palette/white30 |
| iconInverted | Palette/white100 | Palette/black100 |
| iconPrimary | Palette/black80 | Palette/white80 |
| iconNegative | Palette/red | Palette/red |
| iconPositive | Palette/green | Palette/green |
| iconSelected | Colors/iconPrimary | Colors/iconPrimary |
| border | Palette/black8 | Palette/white8 |
| borderIntense | Palette/black10 | Palette/white10 |
| borderPrimary | Palette/black20 | Palette/white20 |
| borderNegative | Palette/red | Palette/red |
| borderPositive | Palette/green | Palette/green |
| borderSelected | Colors/borderPrimary | Colors/borderPrimary |
| borderFocused | Colors/borderPrimary | Colors/borderPrimary |
| background | Palette/white70 | Palette/black70 |
| backgroundDisbled | Palette/black2 | Palette/white2 |
| backgroundPrimary | Palette/black100 | Palette/white100 |
| backgroundPrimaryHover | Palette/black80 | Palette/white80 |
| backgroundPrimarySubtle | Palette/black4 | Palette/white4 |
| backgroundNegative | Palette/red | Palette/red |
| backgroundPositive | Palette/green | Palette/green |
| backgroundNeutral | Palette/black4 | Palette/white4 |
| backgroundNeutralHover | Palette/black8 | Palette/white8 |
| backgroundNeutralIntense | Palette/black20 | Palette/white20 |
| backgroundSelected | Colors/backgroundPrimarySubtle | Colors/backgroundPrimarySubtle |
| backgroundSelectedIntense | Colors/backgroundPrimary | Colors/backgroundPrimary |
| Overlay | Palette/black20 | Palette/black60 |
| Input | Palette/black4 | Palette/white4 |

### 文字 Styles 完整表

所有 24 个 Styles 绑定 fontFamily、fontSize、fontWeight 和 lineHeight 变量。字体解析值在读取时为 English 模式，Chinese 由 Typography 模式决定。

| Style 源名称 | 字号 | 字重绑定 | 行高绑定 | 基准行高 |
| --- | --- | --- | --- | --- |
| 12/400/Default | 12 | fontWeightRegular | lineHeight12 | 20 |
| 12/400/Paragraph | 12 | fontWeightRegular | lineHeightParagraph12 | 24 |
| 12/500/Default | 12 | fontWeightMedium | lineHeight12 | 20 |
| 12/500/Paragraph | 12 | fontWeightMedium | lineHeightParagraph12 | 24 |
| 14/400/Default | 14 | fontWeightRegular | lineHeight14 | 22 |
| 14/400/Paragraph | 14 | fontWeightRegular | lineHeightParagraph14 | 28 |
| 14/500/Default | 14 | fontWeightMedium | lineHeight14 | 22 |
| 14/500/Paragraph | 14 | fontWeightMedium | lineHeightParagraph14 | 28 |
| 16/400/Default | 16 | fontWeightRegular | lineHeight16 | 24 |
| 16/400/Paragraph | 16 | fontWeightRegular | lineHeightParagraph16 | 32 |
| 16/500/Default | 16 | fontWeightMedium | lineHeight16 | 24 |
| 16/500/Paragraph | 16 | fontWeightMedium | lineHeightParagraph16 | 32 |
| 18/400/Default | 18 | fontWeightRegular | lineHeight18 | 26 |
| 18/400/Paragraph | 18 | fontWeightRegular | lineHeightParagraph18 | 36 |
| 18/500/Default | 18 | fontWeightMedium | lineHeight18 | 26 |
| 18/500/Paragraph | 18 | fontWeightMedium | lineHeightParagraph18 | 36 |
| 20/400/Default | 20 | fontWeightRegular | lineHeight20 | 28 |
| 20/400/Paragraph | 20 | fontWeightRegular | lineHeightParagraph20 | 40 |
| 20/500/Default | 20 | fontWeightMedium | lineHeight20 | 28 |
| 20/500/Paragraph | 20 | fontWeightMedium | lineHeightParagraph20 | 40 |
| 24/400/Default | 24 | fontWeightRegular | lineHeight24 | 32 |
| 24/400/Paragraph | 24 | fontWeightRegular | lineHeightParagraph24 | 48 |
| 24/500/Default | 24 | fontWeightMedium | lineHeight24 | 32 |
| 24/500/Paragraph | 24 | fontWeightMedium | lineHeightParagraph24 | 48 |
