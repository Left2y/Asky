# 搜索框半透明玻璃与较轻磨砂

## 用户反馈与修改

用户明确否定不透明底色，并提供另一个搜索框的截图作为材质参考：红绿背景和文字轮廓能透过磨砂玻璃看见，浅色外观仍需保留。随后反馈恢复后的磨砂过强。

- 去掉上一版不透明底色及表面渐变；仅减少透明度分支保留不透明背景。
- 背景使用 Clear Liquid Glass，前景输入和图标在玻璃外按系统颜色模式解析，保留独立边缘高光和投影。
- 光学层覆盖比例从 1 降为 0.82，半透明语义遮罩独立叠在其上：浅色 alpha 0.48，深色 0.60。让少量未过滤的文字轮廓透出，减轻完全磨散的观感。0.82 是合成比例，不宣称为公开 API 的模糊半径、Figma Frost 数值或高斯核参数。
- 使用 Clear 避免 Regular 的独立亮暗切换；玻璃仍然允许背景色透出，不承诺不同背景下 RGB 一致。[Apple Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/) 说明两种材质的适配差异。
- 保留尺寸、布局和搜索行为，本次没有加入参考截图中的其他按钮。

## 实际验证

- `xcodegen generate` 成功；README 的 Debug `xcodebuild` 命令加 Xcode 的 `DEVELOPER_DIR`，最终 BUILD SUCCEEDED。
- 同一 Xcode 环境执行核心 `swift test`：130 tests / 27 suites 通过。
- 使用实际 LauncherView / LauncherPanel 和隔离数据库生成桌面探针。背景是独立原生窗口中的红、绿、白条带及中文文字，检查浅色收起、深色收起和浅色展开状态。已查看最终桌面合成截图，背景文字轮廓可见，前景与放大镜清楚。未改变用户系统主题设置。
- 中间尝试原生 tint、超薄材质加玻璃边缘及 NSVisualEffectView 局部 mask，未采用；最终只保留单一 Clear 光学层与独立半透明遮罩。
- 已重开 Debug 产品并确认实际浮窗可见；最终减轻磨砂后再次重开。未打包或安装 Release。
- 原有窗口回归在前一轮的 `initial search must finish` 断言失败，此轮材质调整未改搜索逻辑，也未重新将该回归记为通过。

图片与编译日志位于既有忽略目录 `build/transparent-glass/`，最终截图为 `light.png`、`dark.png`、`light-results.png`。本轮仅以桌面探针检查材质效果，不宣称像素级复刻或用户视觉验收已经完成。

README: updated，中英文同步半透明材质与合成比例。AGENTS.md: unchanged，开发命令和模块边界未改变。保留已有用户搜索、书签、列表与 PRD 改动；沿用 `.gitignore` 中的 `build/` 规则。
