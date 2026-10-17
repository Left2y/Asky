# Dock 显示设置验证

新增“设置 › 通用 › 启动 › 在 Dock 栏显示”，默认关闭；旧配置缺少此字段时保留其他偏好并使用关闭默认值。开启后在应用运行期间保留 Dock 图标，关闭设置窗口不会隐藏；沿用现有 Dock 重开入口与主动退出流程。此设置不修改系统 Dock 的固定项目。

已执行：

- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --dock-only`：通过。使用临时数据目录，验证旧配置迁移、默认关闭、AppModel 变更回调、偏好落盘、真实设置窗口打开/关闭时的 AppKit activation policy，以及重新读取已保存开启偏好后的策略。重启场景为重新创建模型与控制器，未实际重启主应用。
- 检查原生设置窗口截图 `build/dock-settings.png`：启动区域三行开关对齐，新开关默认关闭。截图和回归构建产物沿用现有 `build/` 忽略规则。
- `git diff --check`：通过。

README 中英文已同步使用行为与回归命令。AGENTS.md 无需变更：未改变项目边界或既有构建流程。未测试系统 Dock 手动固定、退出后的固定图标、实际重启主应用或点击 Dock 图标唤起；后者沿用现有 reopen 实现。
