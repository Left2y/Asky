# 文件跨应用拖放与来源图标稳定性

## 修改

- 文件拖放使用原生 NSURL pasteboard writer，每个原文件对应一个 NSDraggingItem，让 AppKit 处理跨应用文件访问授权。避免只手写 public.file-url。
- 拖拽不再顺带复制到系统剪贴板。
- 历史复制写入专用恢复标记，监听器跳过该次写入，避免用当前前台应用覆盖原来源图标与时间排序。外部新复制仍正常记录。
- 单项 eager dragItem 仅用于文字/图片；文件必须走保留整组与原生 writer 的 dragItems。

## 已执行

- Packages/KulaCore：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过。
- `xcodegen generate` 通过；README Debug xcodebuild 通过。
- `env -u SDKROOT DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --files` 通过：监听识别整组文件、复制回读、恢复后来源/时间保持不变、真实系统光标多文件拖放、接收内容逐字节相同、拖放期间系统剪贴板 changeCount 不变、源面板关闭。
- 新编译回归程序 `--drag` 通过文字接收与源面板关闭。
- 新编译回归程序 `ASKY_CLIPBOARD_DROP_POINT=-2000,100 ... --files` 拖入真实 Chrome 本地测试页。DOM 和本地接收服务回读两份文件：复制文件.txt / text/plain / 27 bytes，second.pdf / application/pdf / 21 bytes，全部字节与生成内容一致。PDF 仅是用于验证传输的测试文件，不验证 PDF 解析。
- 最新 Debug 主应用重启到 `build/DerivedData/Build/Products/Debug/Asky.app`，PID 73611；读取实际新窗口得到搜索框与固定/筛选按钮。随后窗口隐藏，未将额外剪贴板快捷键尝试记为通过。
- README 中英文同步拖拽不改写剪贴板及复用历史保留来源图标；AGENTS.md 无新的持久命令、模块边界或项目结构变化。

## 限制与诊断

- 微信有用户正在编辑的消息，未改动会话或执行文件发送；微信与 Orca 的真实接收窗口仍未验收。
- 原生回归与 Chrome 通过后，日志仍有 sandbox_extension_consume failed。因此这些日志仅是诊断线索，不能单凭其出现/消失认定某个目标是否接收成功；通过结论来自目标数据回读。
- 早期外部坐标误落在源面板/其他窗口，没有网页接收数据，未记为 Chrome 复现证据；最终以明确前台测试页和负坐标副屏目标验证。
- 已经被旧行为覆盖的来源无法可靠还原，本修复防止继续覆盖。
- 测试日志、fixture、测试服务、二进制与截图复用已有 build/ 忽略规则，不进入提交。

## 参考

- [Apple 原生文件拖放文档](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DragandDrop/Tasks/DraggingFiles.html)
- [Chromium 文件 pasteboard 读取实现](https://chromium.googlesource.com/chromium/src/+/HEAD/ui/base/clipboard/clipboard_util_mac.mm)
