# 白底微质感功能图标

根据用户对截图的反馈，将书签、链接与关闭的蓝灰底板改为白色。书签和链接使用柔和蓝色纵向渐变，关闭使用红色电源符号。符号下方增加 0.3 pt 下移、14% 透明度的细微边缘，底板只保留极淡描边；不使用强玻璃或外部投影。使用可编辑 SVG，未使用此前生成的玻璃图片。

## 实际验证

- `xcodegen generate` 与 README 的 Debug `xcodebuild`：通过。
- 原生 AppKit 预览加载新构建的 `Assets.car`，检查三枚图标在深浅背景的 24/48 pt 效果：`build/white-launcher-icons-preview.png`。
- 更新临时启动器回归 app 的资源，执行此前编译的排序、范围与深浅窗口截图流程：通过。查看新生成的 `build/quit-asky-results-NSAppearanceNameDarkAqua.png`，退出入口已显示白底红色电源符号。
- 本次仅修改 SVG 和文档，未修改 Swift，也未重跑核心测试或完整退出确认回归。完整退出确认仍以上一份记录中的 `QuitSheetMissing` 为限。

README 中英文及设计系统同步；AGENTS.md 无新增命令或架构变化。预览与临时 app 沿用 `build/` 忽略规则，未替换已安装应用。
