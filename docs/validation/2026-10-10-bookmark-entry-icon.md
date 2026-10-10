# 书签搜索入口图标修复

- 原因：`bookmark-search` 入口的主动作是 `.open`，落入书签/关键词共用的地球图标兜底分支。
- 修复：入口按 target kind 使用现有 `Bookmark` 图片资源；真实书签链接继续使用默认浏览器图标。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 初次直接 `swift test` 因工具链找不到 `Testing` 模块失败；改用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 重启 Debug App，通过 Orca computer 输入 `kimi`，截图已确认“搜索书签”入口显示蓝色书签图标。
- 本轮未打开书签链接或执行真实书签搜索。
- README 已同步中英文入口图标说明；AGENTS.md 的命令与架构约束无变化。
