# 文件搜索范围：原生文件夹选择

日期：2026-10-11。

- 将通用设置的手输目录路径改为“选择文件夹…”按钮。通过 ToolService 打开 NSOpenPanel，以设置窗口的 sheet 展示，仅允许选择单个目录；确认后追加路径，取消不修改，重复路径不追加。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：退出码 0。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-settings-regression.py --preview`：成功编译并启动独立测试设置窗口。通过 Orca 实际点击按钮，观察原生选择窗口；普通文件显示为禁用。确认 Documents 后，列表新增 `/Users/niallyoung/Documents`；再次确认同一目录仍只有一条；取消后列表不变。使用临时 AppModel 数据，不修改真实应用的搜索配置。
- 随后执行 `python3 App/Tests/run-settings-regression.py`：编译阶段因共享 DerivedData 中 MCPGateway.o 在构建中被修改而失败。直接执行先前已编译的 `build/SettingsRegression.app/Contents/MacOS/SettingsRegression`：退出码 0，输出 `Settings native light/dark snapshots passed`。
- README 中英文使用说明同步。AGENTS.md 无新增持久规则，保持现状。构建与测试产物沿用现有忽略规则。
