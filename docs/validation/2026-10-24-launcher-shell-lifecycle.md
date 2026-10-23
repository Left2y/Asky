# 启动器轻量外壳复用与首帧诊断

## 实现与结论

启动器隐藏后保留原生 `NSGlassEffectView`、包装容器、主 `NSHostingView` 和搜索输入框；搜索结果、动作菜单、状态与终端展示按新会话重新挂载。隐藏先使会话失效，取消布局与搜索、移除辅助窗口、结束输入编辑并卸载重内容。旧几何、菜单和状态回调不能写回新会话。任务执行仍遵循既有模型的生命周期。

首次显示先设置目标屏幕上的最终收起帧，再安装内容、完成布局与圆角、取得输入编辑器、绘制并显示。再次打开重新计算屏幕与可用高度，保持输入框身份。保留顶部锚定画布、原生玻璃材质、系统阴影与现有 0.18 response 的展开/收起弹簧，没有增加遮掩用的延迟、渐入或自绘背景。

**本次没有确认用户所述偶发白块的异常帧，不能宣布该问题已修复。** 轻量外壳复用、资源卸载与首次焦点时序分别验证；原调查记录见[白块调查](2026-10-24-launcher-white-flash-investigation.md)。

## 实际执行的检查

```sh
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --shell-lifecycle
```

KulaCore：43 个测试、10 个测试套件通过。Debug 构建通过。以下模式使用同一 runner 编译的实际 App 视图代码，随后直接调用其 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression` 执行：

| 模式 | 实际结果 |
| --- | --- |
| `--shell-lifecycle` | 浅色、深色各 100 次会话；玻璃、hosting view 和输入框身份稳定；每种外观 10 个真实结果滚动视图在隐藏后释放；取消、迟到结果、跨屏与模拟组合输入清理通过 |
| `--first-presentation` | 每种外观一次冷建、九次复用；初始尺寸/裁剪、同步编辑器、重复打开和隐藏结果释放通过；实际查看两张静态窗口截图 |
| `--result-motion` | 两种外观通过；输入框与窗口顶部漂移均 0 pt；键盘选择、清空收起、动画打断与重开通过 |
| `--fixed-expanded` | 两种外观通过；单条、多条、计算、窗口模式、清空和重开尺寸检查通过 |
| `--app-opening` | 两种外观通过；异步打开前隐藏与结果清理、旧操作等待期间的新会话、应用丢失错误检查通过 |
| `--command-transition` | 两种外观通过；模式内查询保持展开，回空根搜索收起 |
| `--accessories` | 两种外观通过；字段宽度、分类隔离、失焦/Escape 关闭与重复打开通过 |

回归过程中一轮结果动画检查曾在清空后未满足断言，同一二进制复查通过；后续最终代码再次执行也通过，未据此更改动画。另发现旧 accessories 检查固定在清空 220 ms 时要求弹簧完全收敛，浅/深色会偶发采到中间帧。现改为每 10 ms 检查、最多等待 600 ms，最终仍要求回到 52 pt；没有改变产品动画参数。

额外执行 `python3 App/Tests/run-launcher-terminal-regression.py`。旧 runner 将程序作为裸二进制启动，缺少主 bundle 的 `Assets.car`，先在 MingCute 图标查找处终止；本次按现有窗口回归的方式改为打包测试 App，携带图标与核心资源。打包后的首次执行在裸终端前缀断言失败，同一二进制复查通过：设置兼容解码、终端应用选择/图标/持久化、原生输入的 `>` 前缀、空格进入模式、重定向文本、Backspace 与关键词替换均通过。没有把首次失败推断为产品缺陷，也未更改产品终端行为；未执行实际 Terminal handoff。

## 内存与释放边界

生命周期回归在第 1、11、21…91 次会话隐藏并释放结果后采样 RSS（KiB）。最终一次运行：

- 浅色：`96384, 115632, 117680, 117840, 118032, 118416, 118480, 118528, 118544, 118624`。
- 深色：`121520, 121392, 121456, 121520, 121504, 121552, 121584, 121552, 121584, 121616`。

浅色首次预热后增长趋缓，深色后段约 121,500 KiB，基本稳定。对象级检查确认旧结果滚动视图释放、隐藏树内不含结果滚动视图、没有残留子窗口，辅助窗口数有界。该短时样本不构成长时间运行或整个进程内存的严格上限。

## 连续录像与覆盖范围

```sh
python3 App/Tests/run-launcher-presentation-diagnostic.py --output build/launcher-presentation/baseline-fixed
python3 App/Tests/run-launcher-presentation-diagnostic.py --output build/launcher-presentation/current
```

基线在生命周期改动前使用旧显示/隐藏实现构建；只加入了隔离诊断、跟踪及固定屏幕能力。每组浅色、深色各 20 个独立进程，每个进程显示、隐藏、再次显示；半数组使用原 Debug bundle、半数组使用复制到新路径的同一 bundle。启动前先开始裁切区域录像，使用临时数据和空搜索源，不启动正常服务、AI、更新器或搜索授权请求。修改后的诊断进一步记录 AppKit key/expose/close 通知与窗口几何；这不是用于衡量产品打开速度的基准测试。

首轮基线未固定屏幕，鼠标跨屏使部分展示跑出录制区域，故不作为有效对照；已补录 `baseline-fixed`。录制请求 60 fps，但 ScreenCaptureKit 只交付变化帧，基线浅色最大完整帧间隔约 233 ms，深色约 50 ms；不能当作每个合成帧都被捕获。已对录制帧作左下区域亮色矩形候选筛查，并查看抽样联系表，未确认白块。候选筛查不能排除更小、更暗、区域外或落在捕获间隙内的异常。

修改后同样完成 40 个独立进程（每种外观 20 个），共 80 次显示。完整变化帧为浅色 995 帧、深色 1235 帧；最大帧间隔分别约 617 ms、40 ms。左下区域的简单亮色矩形筛查在浅色无候选，深色候选来自背景窗口中的持续亮色区域，查看后没有确认瞬时白块。已查看两组联系表及候选帧；未逐个肉眼审阅全部帧，也没有建立稳定复现基线。

修改后日志确认每个进程只发生一次 `content-installed`、两次 `editor-focused` / `ordered-front`，第二次打开保留原内容树。观测到 AppKit 创建 `TUINSWindow` 与 `SPRoundedWindow`；采样中它们均不可见，不能因名称或左下位置就认定为白块来源。

诊断程序拒绝没有隔离诊断入口的普通/Release App；已用日常安装路径验证启动前拒绝，退出码为 2，未启动或替换该安装。

## 尚未证明的事项

- 没有覆盖真实正式更新器的安装替换、签名验证与真实数据迁移；复制 Debug bundle 路径不等于正式更新后的首次运行。
- 隔离入口跳过常规服务初始化，不能排除正常启动期间其他系统/输入法窗口造成的闪块。
- 模拟 marked text 验证了会话切换的清理，未验证用户物理键盘和具体中文输入法的完整组合输入体验。
- 静态截图、断言通过和未确认候选帧都不能证明偶发白块消失。用户再次观察到时，应结合相应录制时间和窗口日志继续定位。
