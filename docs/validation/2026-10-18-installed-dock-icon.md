# 安装版 Dock 图标同步验收

## 定位

用户截图仍是厚白框旧图标。构建包的 CFBundleIconFile/CFBundleIconName 已为 AskyNative，但 /Applications/Asky.app 仍为 AppIcon。此前分层图标验证没有更新安装版。正在运行的 Debug 进程经重启及 Dock 刷新后也仍显示旧图标，不能仅凭构建包或 NSWorkspace 图标读回认定 Dock 已更新。

## 实际操作与验证

- 安装版完整备份到 build/icon-install-fix/Asky-before.app。
- 将已构建的 AskyNative.icns、Assets.car 同步到安装版，将两个图标 plist 入口改为 AskyNative，保留安装版可执行文件、版本及内置运行时。
- 使用原 Asky Local Signing 身份重新签名并保留原 entitlements、requirements、flags、runtime；codesign --verify --deep --strict 成功。
- 刷新 LaunchServices、图标服务及 Dock，退出 Debug 进程后从 /Applications/Asky.app 启动。
- 进程路径读回为 /Applications/Asky.app/Contents/MacOS/Asky。
- 目视检查 build/icon-install-fix/installed-running.png，Dock 显示放大的浅蓝小伙伴和深蓝底，无外层厚白框。安装版 NSWorkspace 图标读回也为新图。
- 重新签名后的安装版启动时出现系统钥匙串授权窗口，需要用户自行输入登录密码；未操作凭据，也未完成该授权后的功能验收。

本次未修改源码，未重新构建或运行测试，未发布 Release。README 已准确记录正式图标源与构建流程，无需修改；AGENTS.md 无新的持久规则变化。备份、截图和清单由既有 build/ 忽略规则覆盖。
