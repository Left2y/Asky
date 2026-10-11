# 系统权限请求与玻璃授权弹层

日期：2026-10-11。

## 实现

- 辅助功能、屏幕录制保留设置列表行，点击“去授权”打开原生 sheet；已授权显示“重新授权”。弹层使用现有 Theme 颜色、24 pt 圆角与原生 regular Liquid Glass。减少透明度时使用不透明语义背景。
- 弹层包含当前运行应用的图标、可拖拽应用卡片、系统设置入口、Finder 定位与旧条目删除后重新添加的指引。外部拖拽仅导出当前 Bundle 的 `public.file-url`，不查找或复制其他同 bundle ID 应用。
- AppTranslocation 临时路径不提供拖拽，提示先移到应用程序并重新打开。
- ToolService 调用 `CGRequestScreenCaptureAccess` 和 `AXIsProcessTrustedWithOptions`。Boolean 未授权状态允许用户显式请求；其他已拒绝权限继续只提供系统设置恢复，不循环弹窗。
- 返回前台、关闭弹层、页面处于活动状态时刷新实际权限。添加、删除和开启系统开关由用户在系统设置完成；弹层不自动操作 TCC 或开关。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过，共 162 个 Swift Testing 测试。新增 3 项测试覆盖显式权限请求策略、临时/非应用 URL 拒绝、含空格路径导出的精确 file URL；没有在单元测试中请求真实权限。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，最终构建包含本次中英文文案。
- `python3 App/Tests/run-settings-regression.py`：通过，浅深色设置快照与设置窗口导航/布局检查通过。图片及回归应用位于已忽略的 `build/`。
- 重启并打开真实 Debug Asky，通过 computer-use 检查了两项“去授权”、弹层标题/图标/拖拽卡片/玻璃背景、关闭后回到权限列表。录屏及辅助功能弹层均点击了系统设置入口并核对了目标页面。
- 当前系统录屏页面能看到 Asky，开关为关闭；辅助功能对应页面在此系统显示为“设备控制和数据访问”，其中已有 Asky 开启条目，但当前 Debug 进程检查仍为未授权。此差异不能作为当前构建已获授权的证据，也不能仅凭列表旧条目宣称通过。
- `git diff --check`：通过。

## 尚未完成的系统验收

没有在本轮自动删除旧条目或开启开关。真实跨应用拖入后的添加/认证、删除重加后的权限恢复、必要的应用重启、减少透明度实机设置以及浅深色弹层在不同背景上的材质，尚待系统交互验收。已完成的 native snapshot 检查不替代上述验收。

## 文档维护

README 中英文同步了弹层入口、拖入授权、重新授权与临时路径提示。AGENTS.md 的 ToolService 边界与既有构建命令仍适用，无新增持久规则。
