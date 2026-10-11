# 应用语言配置验证（2026-10-11）

## 实现

- 通用设置新增应用语言，默认跟随系统，可选简体中文与 English；变更在下次启动时生效并显示提示。
- 偏好配置兼容旧版本和未知语言值，不丢弃其他配置。
- ToolService 写入当前应用的原生 `AppleLanguages` 覆盖；跟随系统删除该覆盖，不修改系统全局语言。
- 加入中英文 `.lproj` 资源（267 条界面文案及各 4 条系统权限用途说明），覆盖设置、菜单、启动器、剪贴板和 AI 界面常用控件。AI 回复、用户输入、历史内容及工具业务返回文本不由此设置翻译。

## 已实际执行

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：148 项 Swift Testing 测试通过，包含语言覆盖、清除覆盖及保留其他偏好测试。
- `xcodegen generate`：成功生成工程；开发语言 zh-Hans，包含 en 与 zh-Hans 资源。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：Debug 构建通过。
- `python3 App/Tests/run-application-language-regression.py -AppleLanguages "(en)"`：迁移、未知语言回退、持久化、系统覆盖清除、AppKit 菜单、中英文资源选择及全部设置页面标题通过。
- 原生隔离回归窗口分别以 `(en)`、`(zh-Hans)` 和 `(fr, en)` 启动：通过，后者选择支持的 English。
- 实际运行原生设置回归窗口，检查 `build/application-language-en.png` 与 `build/application-language-zh-Hans.png`：语言设置行及说明可见，英文说明正常换行。NSView 缓存截图的材质侧栏呈黑色，因此不将它作为侧栏合成效果的验收证据；未重启当前用户的主应用。
- `plutil -lint`：四份语言资源通过；`git diff --check`：通过。

## 文档与 Git

- README 同步中英文语言说明和回归命令；AGENTS.md 无需更新，模块边界及开发流程未改变。
- 生成的构建、回归程序和截图沿用现有 `build/` 忽略规则。
- 未创建提交：本次修改涉及工作区既有未提交改动，以及原本未跟踪的 `App/Sources/EditMenu.swift`，无法安全构建包含全部本次改动且不包含既有内容的提交。保留既有改动。
