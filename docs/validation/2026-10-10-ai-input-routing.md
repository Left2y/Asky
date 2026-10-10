# 自然语言 AI 路由与结果提示

## 修复

原先普通文本全部路由到本地搜索，AI 动作固定追加在末尾。因此“帮我梳理一下日程”没有本地命中时会默认选中“搜索书签”入口。

增加保守的本地对话识别规则：明确的请求与问题显示唯一 AI 动作，默认选中，普通 Return 将原文交给 AI 对话。输入本身不启动模型。应用名、文件片段和不确定的输入继续本地搜索；计算、换算和显式关键词优先，书签作用域由现有输入状态处理。规则识别并非完整语义分类，未命中的请求仍可选中 AI 或用 Cmd Return。

所有 AI 搜索条目移除“⌘↩ 提交给 AI”副标题。模型发布结果时避免重复追加 AI 动作。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 Packages/KulaCore）：133 项测试通过，含自然语言请求、名称/片段搜索、显式命令优先及空副标题。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --ai-routing`：真实 AppKit/SwiftUI 搜索窗口在浅色、深色模式通过。使用隔离数据库和合成提供者，验证默认选择、Return 回调恰好一次、输入不发送、无副标题、取消的旧查询不覆盖 AI、本地名称搜索与显式关键词保留。

初次 `swift test` 使用 Command Line Tools 时缺少 Testing，改用 README 指定的 Xcode DEVELOPER_DIR。初次新断言把默认空字符串副标题当成 nil；修正测试后重跑通过。

已重开项目 Debug App。Orca computer-use 获取运行 App 的窗口受辅助功能读取阻断；权限状态显示 granted，但 Finder AX 读取仍报 permission_denied。未获得主 App 截图，不把它计为视觉验收。原生隔离窗口检查已实际运行；Return 的测试使用回调收集器，未发送真实模型请求、未读写真实日程。

README 中英同步路由、回车操作、无副标题与专项验证命令。AGENTS.md 不变：模块边界和开发流程未改变。构建与回归二进制使用已有 build 忽略规则。
