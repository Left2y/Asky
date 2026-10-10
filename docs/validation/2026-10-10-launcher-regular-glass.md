# 搜索框改用 Regular Liquid Glass

用户对 Clear 方案的模糊与透明度不满意，最终明确要求直接用 Regular 玻璃材质。

背景直接使用 `.regular`，配合原有 `background` 变量（浅色 white70、深色 black70）；删除 Clear、整层 0.82 透明度和独立遮罩。减少透明度时使用 identity 与不透明底色。保留已有边缘高光、外部阴影、窗口几何与输入行为。采用原生 Regular 的背景适配，不再承诺材质不会根据背景调整亮暗。

## 实际验证

- `xcodegen generate` 成功。
- README 的 Debug `xcodebuild` 命令加 Xcode `DEVELOPER_DIR`：最终 BUILD SUCCEEDED。
- 本轮相同 Xcode 环境的 `swift test`：130 tests / 27 suites 通过。
- 使用生产 LauncherView / LauncherPanel 和隔离数据库，在独立红、绿、白文字背景窗口上检查浅色收起、深色收起及浅色展开。已查看最终浅深色桌面合成截图，原生磨砂与前景放大镜可见；未修改用户的系统主题。
- 最终 Debug 产品已重开。未安装或打包 Release，未声明用户视觉验收通过。

本地截图与日志位于既有忽略目录 `build/launcher-frost-restored/`，最终 Regular 截图为 `light.png`、`dark.png`、`light-results.png`，构建日志为 `app-build-regular.log`。前一轮窗口回归的 `initial search must finish` 失败未重新验证，不记为通过。

README: updated，中英文同步 Regular 材质。AGENTS.md: unchanged，开发命令与模块边界未变。沿用 `build/` 忽略规则；提交仅包含本次材质及对应文档，保留其他用户改动。
