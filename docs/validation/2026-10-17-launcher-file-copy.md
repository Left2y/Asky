# 启动器文件与 App 拷贝验证

日期：2026-10-17。工作区：`/Users/niallyoung/orca/Asky`。

## 行为

- 文件与 App 结果的更多菜单提供「拷贝 ⌘C」。通过 ToolService 模块中的 `ClipboardAccess.copyFile` 写入真实文件 URL，保留原路径复制操作。
- 拷贝后关闭更多菜单并显示提示，保留启动器、查询与结果选择。输入框有文字选区时，⌘C 交给原生文字复制；输入法组词期间不拦截。
- 原文件不存在时不清空剪贴板，并显示失败提示。
- 保留同工作区并发实现的访达操作区入口与按钮样式。

## 已执行

- `xcodegen generate`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，13 个测试运行合计 261 项。
- README 的 Debug 构建命令：通过。
- 为避免并发构建覆盖共享产物，另执行独立目录构建：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/CopyFileDerivedData -clonedSourcePackagesDirPath build/DerivedData/SourcePackages build
```

结果通过。独立目录的 `SourcePackages` 使用指向共享依赖检出的本地符号链接，产物仍独立。

```sh
ASKY_DERIVED_DATA="$PWD/build/CopyFileDerivedData" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --action-bar
```

最终运行通过浅色、深色真实窗口检查：文件 URL 与 Notes.app URL 回读、菜单回车拷贝、菜单打开时 ⌘C、原有路径复制、失效文件保留剪贴板、查询与选择保留。文字选区检查确认快捷键拦截返回 false，再调用原生编辑器复制；测试程序直接向面板派发事件，没有通过应用的编辑菜单。

已查看本次真实窗口菜单截图。截图、测试应用与构建产物均由已有 `build/` 规则忽略。

## 范围与限制

- 未替换 `/Applications` 中的安装版本，未发布 Release。
- 验证了剪贴板文件 URL 载荷；未在访达中实际粘贴，也未测试第三方聊天应用接收文件。
- 初次窗口测试曾受并发编辑/共享构建产物修改影响，随后修正测试夹具并使用独立构建目录，以上通过状态仅指最终运行。
