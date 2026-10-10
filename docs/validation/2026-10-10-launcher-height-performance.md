# 搜索窗口高度、异步列表与关键词输入修复

日期：2026-10-10。

## 改动

- 保持搜索输入框位于当前屏幕上方 22% 处，根据 visibleFrame 中剩余的 78% 高度限制外壳，底部保留 24 pt；结果在列表内滚动，透明阴影不计入可见外壳高度。
- 分类使用独立 VStack 身份范围，结果及键盘滚动使用 SearchResult 的稳定 ID，避免批次更新时跨分类复用旧行。
- 每次输入立即取消旧搜索，普通 Provider 查询延后 100 ms 合并；关键词解析、命令模式切换和确定性结果仍立即更新。新输入重置选择为首项。
- ToolService 对应用/文件图标使用最多 128 项的 NSCache，浏览器 handler 缓存 5 秒并按 scheme 失效，减少 SwiftUI 重绘中的重复系统查询。
- 关键词分隔符接受 Unicode 空白，覆盖中文输入法全角空格；新增 go 全角空格后输入 kimi 的状态回归测试。

## 已运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：128 tests / 27 suites 通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- README 中的原生输入框回归编译与运行：通过，覆盖 go 单半角空格切换、正文输入、空正文退格退出及恢复普通搜索。
- 已退出旧 Debug 进程并打开新构建。computer-use 取得一次命令模式窗口截图，但后续 observation 返回 window_not_found，未完成 kimi 多结果窗口及实际键入的 UI 自动化。

## 验证边界

没有记录输入延迟 P95，也未完成多显示器、明暗主题或 Dock 实机几何验收；不把构建、单元测试或单次截图记作这些检查通过。全角空格通过输入状态单元测试验证，尚未执行真实中文输入法组合输入验收。
