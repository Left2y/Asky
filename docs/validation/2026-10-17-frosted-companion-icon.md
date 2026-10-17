# 浅蓝磨砂小伙伴正式图标

后续用户实屏发现 Dock 白框问题，本次静态资源交付不构成 Dock 验收。正式入口已改为 Icon Composer 分层资源，见[原生图标修正记录](2026-10-18-native-composer-icon.md)。

## 定稿与资源

用户确认的方向：浅蓝磨砂、圆润无触角、歪头微笑、深蓝底与放大裁切；没有蓝紫炫光、侧肢或额外装饰。

- `App/Branding/Logo.png`：1024×1024 RGBA 正式主图，四周透明，图形约占画布 80%。
- `App/Branding/Asky.icns`：独立 macOS 图标包，含全部十种 1x/2x 表示。
- `AppIcon.appiconset`：按现有 Contents.json 生成全部 16/32/128/256/512 pt 的 1x/2x 资源。
- `AskyLogo.imageset`：512 px，共享于设置中的关于页与个人记忆标识。
- `App/Branding/Mark.svg` 与 `StatusIcon.imageset`：同一圆润小伙伴的简化单色轮廓，透明眼睛与微笑，18/36/54 px，保留模板渲染配置。

使用内置 imagegen 从用户批准的对比图提取独立图标。提取提示要求保留原有无触角轮廓、表情、材质和深蓝底，去掉展示背景与右侧小图，输出四周透明且约有 10% 安全留白的单图；不重新设计，不增加高光或装饰。随后进行格式整理：清理 alpha 小于 32 的背景残留，裁切有效边界并归一至 824×824，居中放入 1024×1024 透明画布，以 Lanczos 缩放导出各尺寸。单色矢量轮廓经系统 sips 栅格化，再生成菜单栏尺寸。

## 实际执行的检查

- `xcodegen generate` 成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build` 成功；最终资源更新后的增量构建同样成功。日志：`build/branding-formal/xcodebuild.log`。
- 十种 AppIcon PNG 尺寸均与 Contents.json 一致，均为 RGBA，角落透明。
- `iconutil` 成功解包独立 `Asky.icns` 并读回十种 PNG；编译包中的 AppIcon.icns 也可解包，256 px 图已目视检查为新图。
- 18/36/54 px 菜单栏 PNG 尺寸及 alpha 范围通过检查；没有把该检查当作菜单栏实屏验收。
- 以 `--test-banner` 启动新构建的 App，在真实提醒卡片左上角目视确认新小伙伴图标。截图：`build/branding-formal/reminder-preview.png`。这是无业务执行的预览流程；完成后只结束本次新启动的预览进程。
- README 的中英文品牌说明同步更新。AGENTS.md 无需调整，没有引入新的模块、系统边界或开发命令。

## 范围

本次只更新图标与说明，没有修改 Swift 或 AgentRuntime。未替换 `/Applications` 安装版，未发布 Release；未声称完成设置页、系统 Dock 缓存或菜单栏明暗模式实屏验收。原有运行进程和其他未提交功能改动保留。构建与截图产物沿用已有 `build/` 忽略规则。
