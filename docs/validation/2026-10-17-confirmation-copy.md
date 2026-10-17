# 请求确认文案

日期：2026-10-17。环境：macOS 27.0.1，新构建 Debug App。

## 修改

- 确认正文把已解析的操作目标、实际变更和必要说明组织为一个自然语言段落，移除项目符号、字段列表与工具参数展示。标题、正文和按钮继续由原生 NSAlert sheet 排版。
- 删除“操作详情”展开入口及其未再使用的 accessory view 实现；确认和拒绝结果处理不变。
- 日期、地点、标题等修改保留修改前后的值；外部调用仍说明由外部应用请求，重复日程仍说明仅操作本次。
- DEBUG 请求预览改用具体示例并用一句话说明不会执行操作，不再使用“标题：示例”的字段列表。

## 验证

- `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令：通过。
- `(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)`：通过。
- 新 Debug 预览 PID 11670 的实际日程确认窗口已截图和读取：正文为“将修改日程「产品评审」，地点将从「3 号会议室」改为「5 号会议室」。这是预览，点击确认不会执行真实操作。”，辅助功能树只有标题、单段正文和两个按钮，没有展开详情。
- 预览期间用户正在切换页面，未自动点击后续确认按钮；没有真实工具写入。
- 源码检索确认 App / ToolService 中不再包含 `addDetails` 或 `DialogDetails`。
- `git diff --check`：通过。

README: updated，中英文同步自然语言确认与移除展开项。AGENTS.md: unchanged，现有 App 指令已指向设计系统，构建方式与模块边界不变。本地构建产物复用现有 `build/` 和 `.build/` 忽略规则。
