# 启动器圆角与尺寸调整验证

日期：2026-10-09。范围：启动器输入区、外壳形状、图标和列表留白。

## 调整

- 收起时使用 `radius99999` 对应的 Capsule；结果、状态或终端展开后使用已有的 `radius32` 连续圆角，避免大胶囊裁切展开内容。
- 输入区高度从 56 调整为 72 pt，左右留白从 16 调整为 28 pt；搜索图标显式设为 24 pt，图标与输入文字间距为 14 pt。
- 结果列表左右留白 16 pt、上下留白 10 pt，行内左右留白 12 pt，使 24 pt 结果图标与输入图标左侧对齐。列表高度预算同步使用新的垂直留白。
- 保持 `Colors/background` 原生玻璃 tint 与各文字、图标语义变量。减少透明度的底色使用相同外壳形状。

间距是用户视觉反馈对应的布局值，不声称来自 Figma Spacing 变量。

## 已运行检查

| 检查 | 结果 |
| --- | --- |
| `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | 102 项测试、20 个 suite 通过 |
| `xcodegen generate` | 成功 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build` | `BUILD SUCCEEDED` |
| 直接编译生产 LauncherView 的原生布局探针 | 空输入 72 pt；1、3、40、2、0 条结果分别为 137、229、540、183、72 pt，宽度保持 640 pt，顶部保持不变 |
| 40 条结果选中末项、最大列表附带状态 | 整体保持 540 pt |
| 终端输出附带状态、隐藏后重开 | 分别为 410 pt、72 pt |
| 原生浅色收起预览 | 截图确认完整胶囊、24 pt 搜索图标及增加的留白；输入 `kimi` 后读回相同文本，焦点仍在输入框 |
| 原生深色展开预览 | 截图确认 32 pt 圆角、输入与结果图标左侧对齐、结果无明显裁切；方向键输入因前台应用切换未完成 UI 验证，不记为通过 |
| `git diff --check` | 通过 |
| 本地 Debug App 重启 | 72355 退出，最终构建进程为 87377 |

探针使用固定数据，未调用真实搜索、模型或系统工具；预览用固定背景，不表示完成实际壁纸、多显示器、系统减少透明度或全部辅助功能验收。日志、探针和构建产物沿用已有 `build/` 忽略规则。

## 文档检查

已同步设计系统的尺寸与圆角说明。`README: unchanged`：本次视觉调整未改变用法、依赖或开发命令。并行产生的 README、文档索引与 DeepSeek 验证修改，以及原有验收草稿，均不属于本次提交。

`AGENTS.md: unchanged`：现有构建命令、模块边界、子项目与指令链接仍有效。
