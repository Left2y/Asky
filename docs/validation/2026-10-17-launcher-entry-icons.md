# 启动器链接与书签入口图标恢复

- 原因：`6154ffb` 将 `Link`、`Bookmark` 的原始彩色 PNG 替换成 MingCute 单色模板。
- 恢复两组 1x/2x PNG 与原始 Contents.json，并从 MingCute 导入清单移除这两个别名，避免再次覆盖。
- 六个资源文件逐字节比对 `6154ffb^` 一致。
- `xcodegen generate`、README 的 Debug `xcodebuild` 命令执行通过。
- 使用临时原生 harness 编译实际 App Sources，独立临时数据目录和固定 Kimi 链接/空书签 provider，在真实 LauncherController 中输入 `kimi`。浅色、深色均同时出现“打开链接”和“搜索书签”，渲染截图人工检查为原始蓝色彩色图标。
- 截图：`build/entry-icons-NSAppearanceNameAqua.png`、`build/entry-icons-NSAppearanceNameDarkAqua.png`（沿用 build/ 忽略规则）。
- 首次 harness 编译遇到并发修改 MingCute.swift；重试后空书签 provider 缺失导致断言失败，补齐临时 fixture 后通过。未将失败记录为通过，未修改项目测试代码。
- 没有修改 Swift 源码，未运行 KulaCore swift test。未替换 /Applications 中的已安装应用。
- README 中英文及设计系统同步保留原始入口图标的例外；AGENTS.md 无持久规则变更。
