# 窗口搜索操作菜单

- 窗口结果复用启动器现有“更多 / ⌘K”入口，按顺序显示“关闭窗口”“退出应用”，两项均使用 `kTextNegative`。
- 系统操作经 ToolService：按快照中的 AX 身份重新校验选中窗口，关闭该窗口的原生关闭按钮，或向所属应用发送正常退出请求；不强制退出，应用可处理未保存内容或取消退出。
- README 中英文与 PRD 已同步。AGENTS.md 无需改动：沿用现有菜单、ToolService 边界与构建命令。

## 已执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/WindowActionsDerivedData build`：通过（存在其他既有编译警告）。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `ASKY_DERIVED_DATA=build/WindowActionsDerivedData python3 App/Tests/run-launcher-window-regression.py --window-search`：通过。覆盖菜单文案、两项 negative 样式、⌘K、选择移动、Esc、原有窗口搜索模式与取消。初次截图测试在切换外观后立即开菜单，菜单被后续界面更新关闭；等待外观更新稳定后重跑通过。
- `ASKY_DERIVED_DATA=build/WindowActionsDerivedData python3 App/Tests/run-launcher-window-regression.py --window-search-live`：通过。真实独立测试应用的两个同名窗口分别聚焦、恢复最小化；经新增接口关闭指定窗口、拒绝重复关闭已失效窗口、正常退出剩余窗口所属应用。
- `plutil -lint`：四个修改的 strings 文件通过。
- `git diff --check`：通过。

人工查看了新构建的原生菜单浅色与深色截图：两项均为红色，菜单位置及高亮沿用现有样式。截图位于已忽略的 `build/window-actions-NSAppearanceNameAqua.png` 与 `build/window-actions-NSAppearanceNameDarkAqua.png`；构建和测试产物沿用已有 `build/` 忽略规则。

菜单截图使用固定窗口结果；系统操作使用独立真实测试应用。未对用户实际 Chrome、Finder 等应用执行关闭或退出，也未验收各第三方应用的未保存提示行为。键盘回归为合成原生事件，未执行物理按键验收。
