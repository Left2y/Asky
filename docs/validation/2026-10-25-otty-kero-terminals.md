# Otty 与 Kero 终端适配

## 实现

- 终端列表新增 Otty（`io.appmakes.otty`）与 Kero（`sh.kero`），沿用真实 bundle / executable 校验、图标、设置持久化及卸载后重新选择逻辑。
- Otty 使用应用内 Apple Events `do script`，在新窗口执行 `cd <转义目录> && <命令>`。官方接口要求 Otty 1.2+。
- Kero 从已发现的应用包取得可执行文件，通过现有 ToolService 进程执行器传入 `new --focus --dir <目录> -- <完整命令>`；无需额外安装 PATH 命令。15 秒限制只约束交接客户端，不等待用户命令结束；输出及会话由 Kero 管理。
- 未增加 App 层系统操作或界面说明文案。

接口依据：[Otty AppleScript](https://docs.otty.sh/reference/applescript)、[Kero CLI](https://kero.sh/docs/cli)。另核对官方 Otty 1.6.2 包的 Info.plist、Otty.sdef，以及本机 Kero 2.1.19 的 `--help`。

## 自动检查

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
```

核心测试通过：13 个测试目标共 312 条测试。新增检查覆盖 Otty 应用标识、脚本目录转义，以及 Kero 将多行命令作为单一参数传递、不走 AppleScript。Debug 构建通过，仍有 AppUpdater、PermissionSettings 等既有警告。

## 真实终端交接

本机 Kero 2.1.19；Otty 1.6.2 从官方下载，在忽略的 `build/terminal-verification/` 下临时验证，不安装到 Applications。

```sh
ASKY_TERMINAL_HANDOFF_TEST=1 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-terminal-regression.py
```

原生 AppKit 回归先检查设置保存、图标、终端模式进入/退出、重定向与关键词替换，再调用真实 ToolService 给两个终端派发命令。回读 `pwd` 和 `printf` 写入的文件，验证含中文、空格、单引号的工作目录及命令中的引号、分号与重定向。

最终原生回归通过：Otty 与 Kero 均输出 `native handoff and command output readback passed`，程序以 0 退出。已关闭本次 Kero 测试会话、退出临时 Otty、注销临时应用注册并卸载磁盘映像；本地构建与下载沿用既有忽略规则或位于项目外。

测试运行器的直接 Swift Testing 交接尝试曾出现等待，已将可选真实交接检查放入现有 AppKit 回归程序；首次原生回归的 URL 相等检查因目录尾斜杠产生误报，修正为解析符号链接后的路径比较。

## 验证边界

正式签名 Asky 的首次 Automation 授权、拒绝与恢复未单独验证；Otty 1.2 与其他 Kero 版本未做实机检查。本次未打包或发布 Release。
