# 剪贴板显式颜色语法

采用 Tinycast 的保守识别策略：只将完整显式颜色表达式渲染为颜色，无前缀十六进制字符串（例如 `FF9317`、`34C467`、`123456`）恢复普通文本。此记录取代此前无前缀自动识别的行为。

- 十六进制必须带 `#`，支持 3 / 4 / 6 / 8 位。
- 新增 `rgb()` / `rgba()`、`hsl()` / `hsla()`、`oklch()`。
- RGB/HSL 接受逗号语法或空格与 `/` 透明度语法；OKLCH 仅接受空格语法。支持百分比、数值透明度和角度单位 `deg` / `rad` / `grad` / `turn`。
- 只解析完整表达式，支持首尾空白。拒绝无前缀色值、非法分隔符、缺失分量、非有限数字、色名及带额外文字的字符串。输入扫描限制为 2048 字节，去首尾空白后最多 128 字节，避免在预览中处理过长文字。
- 圆形预览下方显示原始颜色表达式，不强制转换为十六进制；复制、粘贴与数据类型保持原行为。超出 sRGB 色域的 OKLCH 预览按 sRGB 分量裁剪，不承诺浏览器级色域映射。
- `App/Sources/ClipboardColor.swift` 是独立实现，语法及颜色空间转换参考 [W3C CSS Color 4](https://www.w3.org/TR/css-color-4/)。无新增依赖，不引入 Tinycast 源码。

实际检查：

- `xcodegen generate` 通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build` 通过；未执行正式签名或公证。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --colors` 通过：检查带前缀十六进制、RGB/RGBA、HSL/HSLA、OKLCH 对应的实际 sRGB 分量结果（经八位色值量化）、透明度、百分比与角度单位；验证原始表达式保留，以及无前缀编号、缺失分量、非法分隔符和非有限数值拒绝。
- 实际检查浅色列表与深色卡片原生窗口截图，RGB 橙色色块和原始表达式完整显示；回归同时生成另外两种主题/布局截图。未重新验证悬停触发或真实 Figma 复制操作。

截图：[浅色列表](../../build/clipboard-color-light-list.png)、[深色卡片](../../build/clipboard-color-dark-cards.png)。生成物沿用现有 `build/` 忽略规则。
