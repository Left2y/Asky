# 剪贴板名称、来源与类型搜索

日期：2026-10-18。

修复图片显示名称为“图片”但无法搜索的问题。搜索匹配正文、来源应用与类型名称，支持空格分隔的组合词，例如“微信 TIFF”；不匹配尺寸字段。类型信息由 ToolService 读取，卡片和列表共用搜索逻辑。所有候选先匹配再截取 100 条，避免较早的图片被较新的文字记录遮住。普通正文中的同名词仍可命中，不引入类型指令模式。

## 实际执行

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。新增回归覆盖中英文图片名称、短词、正文同名词、超过 100 条新记录后的旧图片、来源与类型组合、结果上限、大小写及尺寸排除。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/check-localization.py`：通过，143 个 Swift 源文件。
- `PYTHONPATH=App/Tests DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 build/run-image-search-regression.py --search-only`：通过。沿用 `App/Tests/run-clipboard-regression.py` 的编译、资源与签名流程，在 build/ 中复制测试入口并增加“图片”“TIFF”“Safari TIFF”断言；验证实际 ClipboardController 的卡片和列表结果，以及普通关键词、Esc 与重新打开。原测试入口已有其他任务修改，未写入该文件。

已查看[列表截图](../../build/clipboard-search-only-list.png)及[卡片截图](../../build/clipboard-search-only-cards.png)，输入“图片”后均展示图片。截图来自测试数据窗口；本次未重新验收浅色、玻璃回退或微信实时复制。

README: updated，中英文补充来源、类型与组合词搜索。AGENTS.md: unchanged，没有新增命令或架构规则。build/ 临时脚本、测试入口和截图沿用已有忽略规则。

未创建任务提交：ClipboardWindow.swift 的搜索入口所在代码块已有未提交的筛选移除修改，README 及其他文件也有并行任务修改；无法将完整任务安全拆成独立提交，保留工作区供后续统一提交。
