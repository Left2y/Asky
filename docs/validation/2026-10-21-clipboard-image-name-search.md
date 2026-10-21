# 图片时间戳名称检索

修复图片名称已显示时间戳、搜索仍只匹配正文与旧类型名称的问题。存储层在限制结果数之前匹配本地时间戳名称；ToolService 将名称与来源、类型共同匹配。既有图片记录无需迁移，继续支持“图片”和“Image”类型词。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过。扩展存储层与 ToolService 测试，覆盖年份、部分和完整时间戳、字面下划线、不匹配后缀、名称与来源/类型组合、超过 100 条较新记录后的旧图片检索。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --search-only`：通过。实际卡片和列表均断言年份、部分/完整时间戳及来源组合检索返回图片。
- 实际窗口截图：[列表搜索](../../build/clipboard-image-name-search-list.png)、[卡片搜索](../../build/clipboard-image-name-search-cards.png)。

README 中英文同步检索能力。AGENTS.md 无持久规则或模块边界变化。构建及截图沿用既有 build/ 忽略规则。
