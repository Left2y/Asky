# 网页关键词与 AI 网站预设验证

日期：2026-10-10

- 网页关键词接受普通 HTTP/HTTPS 网址，省略协议自动使用 HTTPS，不再要求 `{query}`。旧数据字段和搜索模板兼容，内置 Google 搜索继续编码查询参数。
- 预设 `chatgpt` → https://chatgpt.com、`gemini` → https://gemini.google.com、`doubao` → https://www.doubao.com/chat/。三个官方入口已读取核对。
- 已有设置通过一次性标记补齐预设，不覆盖同名关键词或应用/快捷指令别名，主动删除后重启不补回。普通网址仅在准确输入关键词时加入普通搜索结果。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：144 项测试、28 个 suite 通过，覆盖普通网址、ChatGPT 无模板问题传参与特殊字符编码、持久化恢复、无效地址、预设补齐与冲突保留、旧搜索模板编码。首次未指定 Xcode 的运行因 Command Line Tools 缺少 Testing 失败；指定 Xcode 后通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。升级初始化首次编译报存储属性初始化顺序错误，改用局部偏好变量后重新构建通过。
- 重启仓库 Debug 产品，通过 Orca 打开设置 › 别名与快捷指令 › 网页关键词。实际界面与可访问性树确认三个预设均已出现在已有配置中，输入框显示普通网址示例，不显示 `{query}`。
- ChatGPT 根网址自动添加 `q` 参数；Gemini、豆包暂未确认可用的问题 URL 传参，设置行及执行结果标注仅打开网页，不传递问题。Google 官方帮助说明 Chrome `@gemini` 入口，但未给通用 URL query 接口：https://support.google.com/gemini/answer/14886647 。
- 界面截图已观察：`55f91646-5c8a-4999-a560-cbf837c8c0c4` 与最终状态 `a182f57a-4854-46f4-bed9-db868ef0d912`（Orca 临时截图，有时效）。最终界面与可访问性树确认 ChatGPT 支持问题提示，Gemini/豆包显示不传递问题。未执行网站登录、发送内容或浏览器回车打开链路。
- README 中英说明与 PRD 已同步；AGENTS.md 保持不变，无新增架构边界或开发命令。未打包 Release 或安装到 Applications。
