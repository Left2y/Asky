# 百度、花瓣、知乎、小红书、微博指令

## 变更

新增 `bd`、`hb`、`zh`、`xhs`、`wb` 五个固定网页搜索指令，默认启用，沿用设置中的独立启停与持久化。输入指令后按空格进入搜索模式；查询中的中文、空格及 `& + # / ?` 经编码后传入网站。设置列表、搜索输入和结果共用 CommandIcon，保留品牌原色与现有尺寸。

品牌 Logo 打包在 Assets.xcassets，显示时不联网。2026-10-17 下载并检查以下官方素材，原始 PNG 或 ICO/JPEG 无损转为 RGBA PNG（JPEG 源本身的压缩保留）：

| 指令 | 图标来源 | 原始尺寸 |
| --- | --- | --- |
| bd | https://www.baidu.com/favicon.ico | 64 × 64 |
| hb | https://huaban.com/img/touch-icon-ipad-retina.png | 152 × 152 |
| zh | 知乎官方 App Store 应用 432274380，通过 Apple lookup API 获取 artworkUrl512 | 512 × 512 |
| xhs | 小红书官网 apple-touch-icon：https://picasso-static.xiaohongshu.com/fe-platform/f43dc4a8baf03678996c62d8db6ebc01a82256ff.png | 180 × 180 |
| wb | 微博官方 App Store 应用 350962117，通过 Apple lookup API 获取 artworkUrl512 | 512 × 512 |

微博和知乎采用清晰的官方应用图标，避免低分辨率 favicon 在 Retina 屏幕模糊。README 中英文和 PRD 同步新增入口。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过，Swift Testing 共 261 个测试。首次发现旧测试固定断言八个指令，更新为十三个指令的明确列表后完整重跑通过。
- 路由回归覆盖五个新增指令：大小写、空格进入范围、空查询、中文与保留字符编码、目标域名、查询参数以及 openURL 动作；知乎保留 `type=content`。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/ExtraCommandsDerivedData build`：通过。
- 中英文 Localizable.strings 的 `plutil -lint`：通过。
- `ASKY_DERIVED_DATA=$PWD/build/ExtraCommandsDerivedData DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --command-icons`：浅色和深色通过。现有检查遍历全部十三条指令，真实输入关键词、空格和 SwiftUI，验证 Logo 资产、对应结果与空查询退格退出。日志旧文案中的“eight”是既有固定字符串，不代表只运行八条。
- 查看 `build/command-icon-NSAppearanceNameDarkAqua-xhs.png` 及五站浅深截图汇总，确认品牌原色、图标槽与输入/结果的一致性。

- 使用 `ASKY_DERIVED_DATA=$PWD/build/ExtraCommandsDerivedData` 运行现有 SettingsRegression 的隔离 runner 副本（`build/extra-commands-settings-regression.py`）：通过。检查十三条指令默认开启、逐项禁用/启用、候选显示与重启持久化；设置页面浅深色截图和最小尺寸检查通过。
- 查看新生成的 `build/settings-dark-keywords.png`：十三行指令及五个新增 Logo 完整可见，复选框、指令文字和右侧名称对齐。

## 网站检查范围

使用“海报设计”请求各目标链接：小红书返回 200，标题为“海报设计 - 小红书搜索”；花瓣返回 200，但静态响应不足以验证搜索结果；百度进入安全验证；知乎返回 403；微博进入访客验证，目标参数保留。未把这些反爬/登录响应记作已验证搜索结果，也未声称已完成登录后的五站人工验收。

## 工作区与维护

保留任务开始时已有的启动器、剪贴板、文案及设计文档修改；只提交本次指令、素材、测试和文档变更。构建、测试 App 与截图使用已有 `build/` 忽略规则，日志在 `/tmp/asky-extra-commands-*`。未安装或发布新版本。

README: updated，中英文同步五个指令与内置品牌 Logo。AGENTS.md: unchanged，本次没有改变开发命令、模块边界或持久开发规则。
