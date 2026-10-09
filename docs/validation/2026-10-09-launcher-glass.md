# 启动器玻璃材质与背景变量验证

日期：2026-10-09。环境：macOS 26.5.2、Xcode 26.6。范围：启动器外壳、主题桥接和输入提示颜色。

## 原因与最终实现

原外壳使用 `.regular`，大面积结果窗口呈现偏厚的磨砂背景。仅换成不带 tint 的 `.clear` 又使外壳过度依赖壁纸颜色，未应用项目已有的 `Colors/background`；深色文字方案在亮背景上也缺少必要分隔。

最终使用原生 `.clear.tint(...)`，tint 直接解析 `Colors/background`：Light 为 `Palette/white70`（#FFFFFF，alpha 0.7），Dark 为 `Palette/black70`（#0E0F11，alpha 0.7）。不修改原始变量、不添加任意颜色或额外不透明覆盖层；玻璃折射与背景采样仍由系统完成。

`ThemeColor` 增加 Color 类型接口，与既有 ShapeStyle 共用解析路径。启动器文字使用 `Colors/text`，输入提示使用 `Colors/textSubtle`；图标、次要文字和选中行沿用各自语义变量。减少透明度时关闭玻璃，用同一背景变量的 RGB 绘制不透明底色。

## 已运行检查

| 检查 | 结果 |
| --- | --- |
| `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | 102 项测试、20 个 suite 通过，包含真实 Runtime 与 MCP Bridge 测试 |
| `xcodegen generate` | 成功 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build` | `BUILD SUCCEEDED` |
| 原生固定背景预览，Light / Aqua | 背景颜色及模糊文字轮廓可透过外壳，前景文字清晰，保留原生边缘折射 |
| 原生固定背景预览，Dark / Dark Aqua，同一亮背景 | `black70` 提供深色玻璃底色，白色语义文字清晰，背景内容仍可透出 |
| 两种外观点击输入框后按向下方向键 | 第二条结果高亮，焦点仍在输入框 |
| `git diff --check` | 通过 |
| 本地 Debug App 重启 | 旧进程 53280 退出，新进程 72355 从最终构建路径启动 |

视觉预览直接编译生产 `LauncherView.swift`，用固定模型和同一窗口中的渐变、文字背景检查原生材质，未读取用户数据或调用搜索 Provider、系统工具和模型。AppKit appearance 与 SwiftUI colorScheme 同时指定；仅覆盖 SwiftUI colorScheme 不能作为完整原生深色材质验证。

通过 computer-use 在实际原生预览窗口截图回读。单独捕获透明浮窗会缺少背后桌面，不能仅凭其白色截图判断通透程度。本轮未自动唤起最终 App 的启动器，也未完成实际壁纸、多显示器、系统减少透明度、提高对比度或全部辅助功能验收。

构建日志、探针与临时产物保存在已有忽略目录 `build/`；生成工程和 plist 沿用既有忽略规则。原有未跟踪的 `docs/validation/acceptance-v1.md` 不属于本次修改。

## 文档检查

已同步设计系统中的实际材质与语义变量映射。`README: unchanged`：本次落实已有变量与原生 Liquid Glass 要求，未改变产品用法、依赖或开发命令，现有中英文说明仍适用。

`AGENTS.md: unchanged`：检查现有指令层级、子项目与链接，未引入新命令、模块边界或独立子项目。
