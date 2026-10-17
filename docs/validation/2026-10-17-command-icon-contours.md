# 指令图标外形修正与前序调整撤回

用户连续反馈图标外框与轮廓异常。此前按留白计算尺寸、放大抖音内部图案的处理没有满足视觉要求，相关记录已标注撤回；本记录不代表用户验收通过。

## 最终实现

- 删除 ChatGPT 的分数尺寸补偿及抖音 1.12 倍内部缩放。
- 共享外槽固定 24 × 24 pt；普通品牌画布 20 × 20 pt，ChatGPT 恢复原先的 24 × 24 pt 画布以容纳资源自身留白。
- 深色/彩色方形底板在自身 20 × 20 pt 方框中使用 4 pt circular 圆角，保持宽高相等。
- Google、ChatGPT、YouTube、GitHub 及终端应用图标保留资源自身轮廓，不再套用全局双重圆角裁剪。
- 内外框使用固定布局，图片保持原始宽高比；不做内部放大。

## 已实际运行

- `xcodegen generate`：通过。
- README 声明的完整 Xcode Debug 构建：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：262 个 Swift Testing 测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --command-icons`：深浅色均通过；已查看新生成的抖音、Google、DeepSeek 实际启动器截图。
- 使用真实 `CommandIcon.swift` 与 `MingCute.swift` 编译本地原生检查程序 `build/icon-shape-check.swift`，加载新构建资源并生成 `build/icon-shape-gallery.png`，已查看整组图标窗口截图。
- 上述检查在深浅色下测得抖音可见外框 40 × 40 px（2x），其中心内容与原图等比绘制结果逐像素一致，alpha 关于横纵轴交换对称；Google 可见范围 39 × 40 px（原图自身透明边缘所致），完整渲染与不裁剪的原图参考逐像素一致。

本轮曾移除全部圆角，用户截图指出直角底板同样不符合要求，已在最终实现中恢复方形底板的圆角，并重新运行构建、核心测试与启动器图标回归。

检查程序、截图与构建产物均沿用现有 `build/` 忽略规则。未替换已安装应用，其他并行修改保留。
