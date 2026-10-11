# 搜索快捷指令预设

新增固定内置入口：`yt`（YouTube）、`dy`（抖音）、`tb`（淘宝）、`jd`（京东）、`bl`（bilibili）、`gh`（GitHub）。输入缩写、空格及搜索内容后，沿用现有启动器路由，以默认浏览器打开对应搜索地址；无需配置或 AI。

## 已执行检查

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。六个入口均覆盖大小写识别、空搜索模式、中文和 `& + # / ?` 参数编码、目标站点及打开 URL 动作；抖音的路径参数单独验证，斜杠保持编码，不变为路径分隔符。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，`BUILD SUCCEEDED`。
- `git diff --check`：通过。

## 验证边界

未启动原生窗口或完成六个网站的真实浏览器搜索验收。只读网页访问中，GitHub 搜索页可读取，其他站点出现抓取限制或浏览器版本提示，因此不计为网站端验收通过。未打包 Release 或安装应用。

README 中英文用法及 PRD 已同步。AGENTS.md 的开发命令、模块边界及指引仍适用，无需修改。构建产物沿用现有忽略规则。
