# Asky 原生界面与设计系统

更新日期：2026 年 10 月 10 日。状态：已核对变量、聚焦搜索与 AI 对话节点，启动器与对话样式已实现，完整视觉与辅助功能验收仍待完成。

界面使用 SwiftUI 与 AppKit 原生组件，应用用户定义的变量和文字 Styles，并使用系统 Liquid Glass。产品流程以 [PRD](PRD.md) 为准；窗口规格按下述已提供的屏幕设计与原型默认值区分。

## 设计来源与检查结果

来源：[Asky Figma，node 6:12](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/KulaHere?node-id=6-12)。

2026 年 10 月 9 日只读检查：node 6:12 为名为 Button 的 PAGE，子节点为 0。文件级数据有 6 个变量集合、106 个变量、24 个文字 Styles，0 个本地 Paint Styles、0 个本地 Effect Styles。没有可从该目标直接复刻的屏幕、组件几何或玻璃效果规范；页面名 Button 不能视为一个已设计按钮组件。

| 集合 | 数量 | 模式与作用 |
| --- | --- | --- |
| Palette | 32 | Default；基础色及透明度阶梯 |
| Typography | 21 | English / Chinese；字体、字重、字号与两种行高 |
| Border | 3 | Default；0 / 1 / 2 |
| Radius | 10 | Default；0、4、8、12、16、24、32、40、48、99999 |
| Opacity | 1 | Default；disabled = 30 |
| Colors | 40 | Light / Dark；语义颜色与别名，2026-10-10 更新 |

后续指定的[聚焦搜索 Field，node 22:348](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/KulaHere?node-id=22-348)为启动器收起状态的设计依据：720 × 60、左 24 / 右 20 留白、12 间距、17 pt `magnifyingglass`（21 × 22 图标槽）、16/400/Default 输入和 “Search” 提示。此节点替代之前的输入区尺寸与玻璃处理。搜索总宽度后续按用户要求调整为 640 pt（包含空状态右侧按钮），AI 窗口初始宽度与剪贴板列表宽度同步为 640 pt，共用 `WindowMetrics.launcherWidth`。

[UI 页 22:293](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/KulaHere?node-id=22-293)中的新聊天 43:1071、AI 对话 42:760、历史记录 38:653 是对话界面的设计依据：720 × 640、32 圆角、70% 语义背景与原生 Regular Liquid Glass、1 pt border。顶部 12 pt 内距、32 pt 圆形按钮与 18/500/Default 居中标题；正文左右 32 pt，用户气泡 16 圆角与 12/10 内距，正文和工具行使用 14/400/Default。工具行保留 8 pt 图文间距，示例搜索图标按实际工具替换。底部外距 12 pt，输入区 24 圆角、最小 44 pt 文字区域、32 pt 附件与发送按钮。顶部增加新对话与可切换置顶按钮；空状态显示 24/500 问候，历史行高 48 pt 并显示更新日期。历史页替换正文和输入区，不保留常驻侧栏；新对话与设置也可从附件菜单进入。Figma 壁纸属于桌面展示背景，不作为 App 资产。窗口阴影由 AppKit 提供，光学效果由系统实现，不声称逐项复刻 Figma 滤镜。见[新对话样式验证](validation/2026-10-10-ai-chat-refresh.md)。

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

语义颜色先递归解析别名，再按模式取得基础值；原生代码名可规范化，但维护明确映射。源名称 backgroundDisbled 保留原拼写，代码可映射到 backgroundDisabled；Overlay、Input 与 InteractionHover 的大写同样在来源记录中保留，原生分别映射为 overlay、input、interactionHover，不偷偷改写 Figma。

2026-10-10 只读复核 Colors 与 Palette：Colors 共 40 项，文件变量总数为 107，Palette 未变。backgroundPrimarySubtle 与 backgroundNeutral 的 Light / Dark 透明度从 4% 调为 6%，Input 从 4% 调为 8%；新增 InteractionHover（Light = Palette/black6，Dark = Palette/white8）。此变量绑定于 Spotlight item 悬停变体 38:459 / 38:460 和 Session history 悬停变体 43:1134，原生结果行和历史行按鼠标悬停使用，键盘选择仍使用原有选择语义。见[颜色同步验证](validation/2026-10-10-colors.md)。

行高是设计目标。SwiftUI 的 lineSpacing 不直接等于总行高，应核对字体度量、基线、中英混排与原生控件内部排版；不能为了完全相等的数字裁切文字。字号与行高在正常大小下按源值应用，并保持系统文本放大与辅助功能可用。

当前没有 Spacing 变量集合。首轮沿用原生控件内距与布局习惯；若需要独立空间 token，应作为新的设计决定记录，不能宣称已从 Figma 导出。

## 文案规范

- 中文文案的末尾一律不加句号（。），适用于设置、对话框、错误提示、空状态、通知、菜单项等所有用户可见的中文文案；句子中间的句号仍可保留
- 中文与英文混排时，末尾标点按整句正文语言决定；纯英文文案沿用英文标点习惯
- 修改本地化键时同步更新 `en.lproj` 与 `zh-Hans.lproj`，中文显示值必须去掉末尾句号

## 界面结构与窗口默认值

AppKit NSPanel 承载快捷入口，普通层级的透明 NSWindow 承载 AI 对话，保留键盘操作、焦点和原工作应用的切换体验。SwiftUI 管理内容；确需原生窗口、选区、快捷键或特定控件能力时使用 AppKit 适配。

| 区域 | 原型默认值与行为 |
| --- | --- |
| Launcher | 宽 640 pt，输入区高 60 pt，高度随结果变化，最大 540 pt |
| Agent | 初始 640 × 640 pt，最小 640 × 560 pt，可调整大小 |
| 输入 | 16/400/Default（node 22:348） |
| 结果主文本 | 14/400/Default |
| 次要说明与快捷键 | 12/400/Default |
| 按钮文字 | 14/500/Default |
| 对话正文 | 14/400/Default（node 43:1052） |

Launcher 收起尺寸与输入文字来自 node 22:348；Agent 初始尺寸来自 node 43:1072 / 38:654，其余尺寸与角色仍为当前实施方案的建议默认值。应在多显示器、长文本、辅助功能放大与真实任务中验证，不能把其余建议归因于空 Figma 页面。

启动器收起时使用 `radius99999` 对应的 Capsule，展开结果、状态或终端时使用 `radius32` 连续圆角。输入区左侧留白 24 pt、右侧 20 pt，搜索图标为 17 pt（21 × 22 槽），与文字间距为 12 pt，来自 node 22:348；结果列表左右留白 12 pt、上下 10 pt，行内左右留白 12 pt，使图标左侧继续对齐。结果布局仍为实施值，不属于 Figma Spacing 变量。见[聚焦搜索验证](validation/2026-10-09-figma-search.md)。

2026-10-17 按用户提供的 Tinycast 截图调整搜索密度，覆盖上文启动器的历史尺寸：输入区高 52 pt、输入字号 16 pt；结果改为 38 pt 单行、24 pt 图标、14 pt 名称与右对齐的 12 pt 类型。分组标题高 30 pt，列表预算为八行（304 pt，分组标题共用预算）。结果行不显示路径或副标题；应用显示“应用”，文件优先显示格式扩展名，目录显示系统类型，其余显示来源类型。路径复制与访达定位保留。2026-10-18 起固定与筛选改为输入区右侧的 32 pt 图标按钮，使用 17 pt 图标，共用外壳玻璃，不绘制独立玻璃背景；移除右侧搜索图标。空输入时显示两个按钮，输入后隐藏并让出文字空间，搜索框始终保持 640 pt 宽，见[内置按钮验证](validation/2026-10-18-launcher-inline-controls.md)；收起与展开时 SwiftUI 裁剪、原生玻璃和内容层统一使用 26 pt 圆弧半径，避免高度变化后端部被拉伸。系统阴影结构保持一致。

交互区至少覆盖输入、可选择结果、附件预览、工具进度、澄清、确认、实际结果、历史与记忆管理。确认界面显示具体目标和变更；“正在启动 AI”立即反馈，但不是承诺 Pi 已经在某个时限内启动。

## 原生组件使用

| 需求 | 首选原生能力 | 保留的行为 |
| --- | --- | --- |
| 输入、搜索与多行任务 | SwiftUI TextField / TextEditor，必要时 NSTextView 适配 | 选区、输入法、粘贴、键盘与辅助功能 |
| 动作、选择与开关 | Button、Toggle、Picker、Menu | 原生语义、焦点、禁用与快捷键 |
| 结果与历史 | 原生列表或有界分页滚动区域 | 稳定目标标识、键盘选择、按需加载 |
| 进度与状态 | ProgressView 与结构化工具结果 | 停止、拒绝、错误与待核实可区分 |
| 附件与来源 | 原生预览、文件或目标打开入口 | 缩略图、查看原件与可追溯来源 |

Theme、ButtonStyle、LabelStyle 或 ViewModifier 只负责样式映射，不重写控件固有行为。不能把可点击文字当按钮、颜色当唯一状态或失去原生输入法行为。功能图标统一使用 [MingCute Icons](https://github.com/mingcute-design/mingcute-icons) 的线性 SVG，选中或运行状态按需采用同库填充版本。图标作为本地矢量模板资产打包，通过 `MingCute` 共享映射供 SwiftUI 和 AppKit 使用，大小显式指定，颜色继承语义前景色。设置侧栏与旧功能资产也使用同库图形。AI 思考过程中的工具调用图标槽统一为 16×16 pt，包括加载、应用、插件与通用图标；日历等工具保留对应 App 的图标，失败状态使用 MingCute `warning` 圆形感叹号，错误详情与行文字对齐。可展开错误的箭头紧跟工具调用 label，不使用圆形或胶囊按钮；点击文字与箭头整体展开/收起。联网搜索使用 MingCute 搜索图标，记忆调用使用 MingCute brain。所有插件（包括 Orca、飞书）统一使用 MingCute tool 图标，工具调用中为 16×16 pt，插件设置保留 36 pt 图标槽；不再加载品牌应用图标或插件自定义图标作为界面标识。自动审批使用用户提供的 `hand_line`（源文件 `App/Artwork/approval-hand.svg`），按钮与审批菜单共享同一映射。聊天与代码块复制采用用户提供的 `copy_2_line`（`App/Artwork/copy.svg`）。Asky 品牌标识、真实应用/网站标识、用户自选图标与内容缩略图保留原始来源。Asky 自有工具入口（链接、书签、换算、标签页、计算器、退出）必须复用 `LauncherFunctionIcon`：使用本地 MingCute 线性矢量模板叠加纯色底板，白色图形 16×16 pt、底板 20×20 pt、外层图标槽 24×24 pt；底板统一裁切 5 pt 普通圆弧圆角（`.circular`），不得使用连续圆角或超椭圆。图形居中，不单独缩放或偏移，不叠加渐变、高光或阴影，不使用预合成 PNG 作为自有工具图标。搜索结果、输入模式与指令设置必须共用相同组件与映射；网站搜索指令与工具共用 `LauncherIconTile.cornerRadius` 的 5 pt 普通圆弧，工具底板直接以固定圆弧路径填色绘制。背景色只允许使用 `ToolIconPalette` 的五个固定颜色，提取自现有入口：书签橙 #FF9A02、换算青蓝 #0091FF、链接蓝 #2D68FF、标签页紫 #7D40FF、退出红 #FF0000。书签使用橙色，退出使用红色，换算与计算器使用青蓝色，链接使用蓝色，标签页使用紫色。不得新增、微调色值或使用透明度变体。对应 MingCute 图形为 link、bookmark、transfer、web、counter_2、power。AI 入口保留原有 `Agent` 品牌图片与 20 pt 显示尺寸，禁止替换为 MingCute 图形或套用工具五色背景。新增自有工具沿用同一组件与几何，只增加语义图形并从上述五种颜色中选择；真实应用、网站品牌 Logo、国旗及内容缩略图保留原始来源，不套用自有工具的白色模板规则。资源版本、完整替换映射见 `scripts/mingcute-icons.json`，Apache-2.0 许可随应用打包在 `App/Resources/ThirdParty/MingCute/`。

### Dialog 与 Alert

应用内提示、错误、安装与更新确认、工具执行确认统一使用 macOS 原生 `NSAlert`，经 `AppDialog` 创建与呈现。有所属窗口时使用 `beginSheetModal` 的原生 sheet；不手动设置应用图标，让 AppKit 省略重复的品牌区并提供紧凑布局。仅启动失败等没有所属窗口的情况回退到独立 alert。外壳、圆角、材质、阴影、文字排版和按钮布局均交给 AppKit，随系统版本和外观设置呈现；不按参考图自绘一套固定外观，也不套用启动器的玻璃窗口结构。

按钮尺寸与排列使用系统默认值（当前系统中两个简短按钮横排、三个按钮纵排），不手动改写按钮 frame。主要操作使用默认按钮，取消或拒绝保留 Escape 行为；确认正文用一段自然语言说明具体目标、变更和必要影响，不展示字段列表、工具名、原始参数或“操作详情”展开入口。系统权限提示、打开与保存面板继续使用对应的系统界面。

## 启动器悬浮操作区

结果底部左侧展示选中项的主要操作，右侧仅在存在附加动作时显示「更多 ⌘K」；没有可用动作时允许两侧都为空。控件使用现有 Regular 玻璃胶囊、语义文字色与 MingCute 图标。它们叠放在结果区域内，不增加固定分隔栏；列表底边使用 alpha 渐隐，让滚动内容在控件下方消退，末尾预留滚动空间，使最后一条结果能完整露出。

更多菜单位于右侧按钮上方，使用独立、非 key 的圆角玻璃子窗口与系统阴影。`⌘K` 切换菜单，`↑` / `↓` 在菜单中选择，`Return` 执行，`Escape` 只关闭菜单；关闭后保持输入框焦点、搜索词与原结果选择。输入改变或选中目标变化时关闭旧菜单，避免将动作应用到其他结果。文件与应用的「在访达中显示」直接置于左侧操作区、紧随主操作，不在更多菜单重复；「复制路径」保留在更多菜单，两者沿用用户配置快捷键；链接与标签页提供「复制链接」。计算结果只显示复制操作，汇率保持只读。实际检查见[悬浮操作区验证](validation/2026-10-17-launcher-actions.md)。

## Liquid Glass

macOS 15 的兼容表面使用 `NSVisualEffectView` 的 `underWindowBackground` 材质与 `behindWindow` 模式，叠加现有 `background` 变量（浅色白 60%、深色黑 60%）及 1pt `border` 描边。设置侧栏与内容区同步适配；按钮降级为原生 bordered / borderedProminent。用户已接受系统控制的背景模糊半径，不要求精确 120px。辅助功能模式保持不透明背景与高对比描边。

macOS 26+ 使用原生液态玻璃；源码构建最低支持 macOS 15。SwiftUI 的 glassEffect、GlassEffectContainer 与原生玻璃按钮样式，以及 AppKit NSGlassEffectView 是实施候选；具体组合与 SDK 可用性在 M0 编译和视觉验证。[Apple SwiftUI Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)、[Apple NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview)

启动器、AI 对话、剪贴板及其玻璃控件、预览和授权浮层统一使用 `NativeGlassBackground`：macOS 26+ 普通模式仅使用原生 `.glassEffect(.regular, in:)`，不叠加 `background` 的黑白填充或自制渐变描边；原生材质负责磨砂、光学边缘和背景适配。按钮可使用 Regular 的 interactive 变体。浮动表面采用 Spotlight 式窗口结构：启动器外壳、筛选菜单、剪贴板主窗口和完整预览各自是一个窗口，窗口帧恰好等于玻璃外形，由 AppKit `NSGlassEffectView` 填满并开启 `hasShadow`，阴影由窗口服务器按可见外形生成；`NSGlassEffectView` 与内容层都按同一圆角裁剪，否则玻璃在窗口角落留下的微弱 alpha 会让系统阴影呈方角黑边。筛选、更多菜单等附属表面是外壳的子窗口；启动器的固定与筛选是搜索框内部的普通图标按钮，共用外壳玻璃，只绘制悬停和按下反馈，不创建按钮窗口或执行分离动画。筛选与更多菜单的非 key 玻璃和 key 外壳的材质差由 `InactiveGlassTintView` 补偿：深色用 5% 白色透明叠层；浅色改用 5% `.plusLighter` 加色叠层，因为普通白色叠层在亮背景接近饱和、补不上约 12 级的暗差。补偿必须在窗口 alpha 入场动画开始前启用：加色叠层在窗口 alpha 动画期间不会被合成，动画中途才启用会等到落定才出现，形成约 12 级的亮度突跳。见[浅色模式非 key 玻璃提亮](validation/2026-10-18-inactive-glass-light-mode.md)。提示条是不透明的独立表面。不使用透明留白画布与自绘阴影（前者被描出偏下黑框，后者曾让浅色玻璃变深）。降低透明度或增强对比度时由 SwiftUI 绘制不透明回退表面。见[Spotlight 式浮动表面](validation/2026-10-16-spotlight-surfaces.md)、[原生窗口阴影](validation/2026-10-14-native-window-shadow.md)与[启动器黑框](validation/2026-10-16-launcher-shadow-outline.md)。

不使用 Clear 材质，避免背景文字直接折射进阅读区。降低透明度或增强对比度时关闭玻璃，改用不透明语义背景和清晰边框。剪贴板搜索框、固定按钮和历史卡片使用不带染色的原生 Regular 玻璃，移除深色语义填充；卡片仅在选中时增加描边。其他内容卡片保留原有内容层。原生材质随背景变化，不承诺固定黑白表面或 Figma 光学参数的逐项等价。验证见[原生玻璃统一记录](validation/2026-10-11-native-glass.md)。

设置窗口以 [Figma node 61:164](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=61-164) 为模板：900 × 640 初始尺寸、220pt 侧栏、32pt 外圆角、16/500 页标题、14/400 正文、14/500 分组标题、12pt 卡片圆角。设置卡片内的单元格标题与辅助说明统一为 14 pt（标题 14/400/Default，辅助说明 14/400/Default 并使用次要文字色）；仅分组页脚、状态提示等外围说明保持 12 pt。整窗共享一层背景，使用 AppKit 原生 Regular 玻璃、聚焦时 25% / 失焦时 55% 明暗语义背景染色，以及聚焦时 6% / 失焦时 3% 中性色层，保留环境色并保证卡片层次，避免侧栏与内容区各自加材质。浅色设置卡片保留 70% 背景色；暗色卡片使用 6% 白色提亮层，避免与整窗玻璃产生过大的明暗差，侧栏选中态使用 `backgroundSelected`；按钮和选择器使用原生默认样式；输入框与密码框保持原生编辑行为，使用低对比半透明背景、6pt 圆角与聚焦描边，避免暗色系统输入背景呈现为突兀黑块。降低透明度或增强对比度时改用不透明语义背景。

- 浮动入口外壳、导航、工具栏与关键操作适合玻璃；使用系统协调的效果容器，避免各层独立叠加。
- 对话正文、长文本与结果内容保持清晰阅读层；剪贴板历史卡片按上述独立规范处理。
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
| background | Palette/white60 | Palette/black60 |
| backgroundDisbled | Palette/black2 | Palette/white2 |
| backgroundPrimary | Palette/black100 | Palette/white100 |
| backgroundPrimaryHover | Palette/black80 | Palette/white80 |
| backgroundPrimarySubtle | Palette/black6 | Palette/white6 |
| backgroundNegative | Palette/red | Palette/red |
| backgroundPositive | Palette/green | Palette/green |
| backgroundNeutral | Palette/black6 | Palette/white6 |
| backgroundNeutralHover | Palette/black8 | Palette/white8 |
| backgroundNeutralIntense | Palette/black20 | Palette/white20 |
| backgroundSelected | Colors/backgroundPrimarySubtle | Colors/backgroundPrimarySubtle |
| backgroundSelectedIntense | Colors/backgroundPrimary | Colors/backgroundPrimary |
| Overlay | Palette/black20 | Palette/black60 |
| Input | Palette/black8 | Palette/white8 |
| InteractionHover | Palette/black6 | Palette/white8 |

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
