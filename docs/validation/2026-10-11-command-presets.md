# 固定内置指令验证

日期：2026-10-11。

## 行为

- AppModel 使用不可修改的内置 KeywordRegistry，不再从旧 `keywords` 设置加载或执行一次性预设迁移。
- `go` 为 Google 搜索、`chat` 为 ChatGPT；`>` 保持原有终端模式。三个入口无需用户配置。
- 移除设置中的网页关键词页面及添加、删除表单；旧的 `keywords` 设置页标识回退到通用。
- 终端应用与工作目录设置保持现有行为。旧关键词数据仍在本地存储中，但不参与启动器路由。
- README 中英文和 PRD 已同步。

## 实际执行

通过：

```sh
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
python3 App/Tests/run-settings-regression.py
```

设置回归使用独立临时数据目录，保存一个将 `go` 指向其他网站且缺失 `chat` 的旧配置，再加载 AppModel，确认固定预设、Google/ChatGPT 路由、无需配置的终端模式、设置页枚举及旧页标识回退。原生设置窗口完成浅色/深色全部页面回归，输出 `Settings native light/dark snapshots passed`。

没有打开真实浏览器或执行真实终端命令；没有打包 Release 或安装应用。截图、测试可执行文件及 DerivedData 沿用已有 `build/` 忽略规则。

## 文档与 Git

- README: updated — 中英文同步固定指令及旧配置不再生效的行为。
- AGENTS.md: unchanged — 没有改变模块边界、开发命令或独立子项目。
- 验证期间其他工作流程创建了提交 `20b1e8b`，包含本次实现及此前语言、粘贴、剪贴板改动。本次不改写该提交；验证记录单独提交。
