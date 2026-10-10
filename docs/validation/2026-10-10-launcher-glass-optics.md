# 搜索浮窗玻璃合成与定向高光

## 依据与问题

用户提供的 Figma 面板参数：Light -45° / 80%，Refraction 50，Depth 40，Dispersion 48，Frost 50，Splay 32；另提供浅色展开搜索的目标截图。用户明确否定上一版仅调整磨砂、填充和投影的外观。本轮 Figma context / screenshot 连接均返回 Unknown tool，未声称已重新读取节点；以用户截图为视觉依据。

上一版 NSVisualEffectView 磨砂、纯色填充、Clear glass 与普通描边叠加，把大部分光学变化压成了平直的雾面板。本轮去掉额外窗口磨砂与纯色遮盖，将单层 Regular Liquid Glass 直接应用于内容。仅减少透明度时保留不透明底色。

## 最终实现

- 系统玻璃负责动态磨砂与光学效果；没有抓取桌面、使用私有 API 或将设计截图作为生产背景。
- 1 pt 定向边缘高光从左上方开始，补充截图中的光照方向；高光梯度是视觉近似，不把 80% 光照强度声称为原生参数映射。
- 普通模式去掉平直的语义描边；减少透明度或提高对比度时恢复语义边框。
- 深色使用原生玻璃自身的 55% 语义黑色 tint，避免明亮背景令玻璃变浅而降低固定原生输入文字的对比。内容颜色显式沿用外层 colorScheme。
- 上一版独立阴影及透明画布保持；输入、结果几何与交互没有修改。

公开 API 依据：[Apple 自定义视图 Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)、[NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview)。当前公开 API 提供玻璃样式、形状和 tint 等设置，不提供 Figma 这套 Refraction / Depth / Dispersion / Frost / Splay 数值。本轮修正合成方式，不声称已与 Figma 光学渲染逐项等价或视觉验收完成。

## 实际验证

- 核心 Swift 包：129 项测试、27 suites 通过。
- `xcodegen generate` 及 README 的 Debug `xcodebuild`：BUILD SUCCEEDED。
- 最初原始窗口回归失败：真实键盘输入混入测试文本，日志出现 `tuafbari` / `tuafbariioa`；该次不记为通过。
- 使用相同生产视图与原始窗口回归脚本，仅将临时测试 Panel 的 canBecomeKey 设为 false 后重跑：浅色/深色通过，初次结果、连续程序输入及结果变化的输入框漂移均为 0 pt。不宣称该不取焦点探针覆盖了真实唤起后的焦点切换。
- 独立透明 NSPanel 与独立色块/文字背景窗口桌面检查：单层 Regular 比上一版保留更多背景轮廓，前景 Safari 结果清晰。已查看浅色结果/收起状态与最终深色 tint 状态。
- 减少透明度和提高对比度分支通过临时探针强制对应只读环境值检查：不透明底色与语义边框可见。未修改用户系统设置，不将此检查记为真实系统设置切换验收。

截图及日志位于本地 `build/`，沿用既有忽略规则：`build/validation/launcher-glass-optics-single-surface.png`、`launcher-glass-optics-final-light.png`、`launcher-glass-optics-dark-tint.png`、`launcher-glass-optics-opaque.png`、`launcher-glass-optics-contrast.png`。测试使用隔离数据库及模拟 Provider；测试窗口已退出。未安装或打包发布版本，未重启用户的产品进程，新效果需重开新 Debug 构建。

README: updated，中英文同步最新材质；设计系统同步实现与限制。AGENTS.md: unchanged，无模块边界或开发命令变化。既有列表高度、链接/书签及其他文档改动不纳入本轮提交。
