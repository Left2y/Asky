# 应用本地化名称搜索验证

日期：2026-10-10。

## 原因与修复

应用索引原来只匹配 `.app` 文件名，导致微信（WeChat）、钉钉（DingTalk）、飞书（Lark）、腾讯会议（TencentMeeting）、QQ 音乐（QQMusic）、剪映专业版（VideoFusion-macOS）等中文名称无法命中。

索引现在缓存文件名、CFBundleName、CFBundleDisplayName 和各 `.lproj/InfoPlist.strings` 中的名称，按最高匹配分数返回同一应用，保留原路径和启动动作。结果标题优先采用当前语言的包内显示名称。兼容 XML/binary plist 与 UTF-16 OpenStep strings，不执行应用代码、不调用模型。

Safari 的公共应用符号链接携带 Finder 隐藏标记，原 `.skipsHiddenFiles` 过滤也导致它被漏掉。现在保留带隐藏标记的 `.app` 入口，仅排除点号开头的内部条目。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：最终 140 项测试通过。回归覆盖中文与英文名称、XML 与 UTF-16 本地化资源、重复 roots、无匹配名称、Finder 隐藏应用与点号条目。
- 本机临时搜索探针：对标准应用目录的 128 个名称逐一调用真实 AppsProvider，并验证对应目标。全部通过；其中 25 个名称原文件名匹配无法命中。包含微信、钉钉、飞书、腾讯会议、QQ 音乐、剪映专业版、Pages 文稿、Numbers 表格、Keynote 讲演和 Safari 浏览器。探针已移除，保留可移植回归测试。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- Debug 产品已启动。GUI 自动化未能通过快捷键切换至启动器窗口，因此此记录不将搜索浮窗视觉流程记为通过；上述搜索结果验证通过实际 provider 完成。

## 范围

保持现有标准应用目录范围及缓存生命周期。本次未增加拼音别名或递归应用目录发现；不将不存在于应用元数据中的名称视为支持。没有打包或安装 Release。
