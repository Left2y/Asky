# 剪贴板统一列表视图

日期：2026-10-21

- 移除卡片视图、卡片专用横向滚动与悬停预览窗口；列表保留搜索、详情预览、单击选中、双击复制和更多菜单。
- 移除设置中的显示方式及对应中英文字符串；移除布局偏好字段。旧数据中的 `clipboardLayout` 由 Codable 忽略，其余偏好继续读取，重新编码不再写入该字段。
- 更新原生回归：删除卡片专用用例，保留列表覆盖；旧卡片配置解码与重编码检查通过。菜单键盘测试先明确选中项，避免外观截图期间的指针悬停影响；回车测试经实际面板事件路由执行。

实际执行结果：

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（工作目录 `Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：最终构建通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：最终通过，覆盖旧配置、玻璃窗口、选中与过滤、长文本滚动、单/双击、复制、回车、更多菜单与提示消失。
- `build/ClipboardRegression.app/Contents/MacOS/ClipboardRegression --delete-shortcut`：通过，删除后保留查询、关闭更多菜单、忽略重复键和额外修饰键。
- `build/ClipboardRegression.app/Contents/MacOS/ClipboardRegression --availability`：通过，覆盖失效原件隐藏、恢复、复制时失效和监控过滤。
- `git diff --check`：通过。

已查看本轮原生窗口截图：[列表图片预览](../../build/clipboard-layout-list-image.png)、[剪贴板设置](../../build/clipboard-layout-settings.png)。设置页保留历史记录开关、保留时间和排除应用等配置，无显示方式选项。

前序回归尝试因编译期间输入文件变更而中止；改为串行并修正旧回归的菜单初始选中项及回车事件驱动后，完整回归通过。没有将前序失败计为通过。编译仍报告既有 AppUpdater 捕获、辅助回归函数 actor 隔离和弃用 API 警告。本轮未执行外部应用自动粘贴或拖放验收。

README 中英文与设计系统已同步。根级及 App 的 AGENTS.md 规则仍适用，无需修改。构建、截图及回归应用沿用现有 `build/` 忽略规则。工作区已有快捷键相关改动保持独立。
