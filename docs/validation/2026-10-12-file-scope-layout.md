# 文件搜索范围布局调整

- 将“添加文件夹…”移到“文件搜索范围”标题右侧，移除独占一行的添加操作。
- 已添加目录显示文件夹图标、路径与移除按钮；长路径中间截断，悬停显示完整路径。
- 空列表显示“尚未添加搜索目录”；排除目录仍保留独立设置行。
- 新文案补齐简体中文和英文。

## 已执行验证

- `xcodegen generate`：通过。
- `(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/FileScopeDerivedData build`：通过。
- 启动上述新构建的 Asky.app（PID 37398），通过菜单打开通用设置，查看实际窗口截图：添加按钮与标题对齐，目录列表无空置按钮行。
- 点击标题右侧添加按钮，实际打开“添加文件搜索范围”原生文件夹选择器；点击取消后返回通用设置，现有 `/Users/niallyoung` 搜索范围与排除值保持原样，添加按钮恢复可用。
- 截图、UI 状态与命令日志保存在已忽略的 `build/file-scope-layout/`。

## 范围与文档门禁

- 未实测空目录、多目录及长路径状态；未新增或移除用户的搜索目录。
- README: unchanged — 小幅布局调整，既有使用方式与开发命令不变。
- AGENTS.md: unchanged — 无持久命令、架构或子项目边界变化。
- 工作区已有其他修改；提交仅包含本次布局、本地化及此验证记录。
