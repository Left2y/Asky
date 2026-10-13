# 排除项逐行列表

状态：输入弹窗版本已验证，但验证后被并行任务改为系统文件／应用选择器。以下结果只覆盖输入弹窗版本，不代表当前选择器版本已验证；本轮因冲突未提交。

将设置 › 通用中的排除目录名、剪贴板排除应用 Bundle ID 改为列表。每项独立一行，右侧编辑和删除；添加／编辑使用输入弹窗，确定后才更新原有数组，取消丢弃草稿。去除首尾空白，空内容和重复项禁用确定。已有数据格式保持不变。

## 已执行验证

- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过（包括 XCTest 和 Swift Testing；Swift Testing 36 项）。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --preview`：编译实际 App 源码并打开临时数据设置窗口。使用新进程 PID 48968 确认目录列表，添加测试项、编辑弹窗预填和保存改名均通过 UI 回读验证。
- 为避免其他并行设置验证进程干扰，将本轮原生回归 bundle 复制到忽略目录 `build/ExclusionPreview.app`，修改 bundle ID 为 `app.asky.exclusion-preview` 并重新 ad-hoc 签名，运行 `--preview`（PID 55791）。剪贴板列表新增、删除、重复项提示、空值禁用确定、目录新增草稿取消均经原生 UI 回读确认。仅操作临时设置数据。
- 运行同一 `ExclusionPreview` 可执行文件（无 preview 参数）：原生设置快照、授权生命周期与卡片拖动回归通过。检查本次生成的 `build/settings-light-advanced.png` 和 `build/settings-dark-advanced.png`，目录列表浅深色显示正常。

验证 bundle 与构建日志属于本地输出，复用现有 `build/` 忽略规则。没有安装或发布应用。README 中英文同步逐项管理说明；AGENTS.md 无持久规则变化。
