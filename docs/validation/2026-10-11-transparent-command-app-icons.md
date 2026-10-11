# 透明留白与指令 App 图标

本记录替代上一轮的白色底板样式；历史验证文件保留当时状态。

## 变更

- CommandIcon 移除人为添加的白色底板及描边，周围留白保持透明。图标素材自身的品牌底色仍保留。
- 24 × 24 pt 布局区域内，普通品牌图标为 20 pt、5 pt 连续圆角；原生 ChatGPT/终端资产保留 24 pt 渲染以补偿自带透明边距。
- 淘宝换为橙色“淘” App 图标，京东换为红色 Joy App 图标，bilibili 换为粉色 App 图标。抖音也换用高清 App 素材。
- Google 换为真正透明的 G 素材；GitHub 换为透明图形并按当前外观着色，确保深色模式可见。
- 设置列表、搜索框和对应结果仍共用同一个组件和资产。

## 资源出处

| 资产 | 发行方页面或资源 |
| --- | --- |
| 淘宝 | https://play.google.com/store/apps/details?id=com.taobao.taobao |
| 京东 Joy | https://play.google.com/store/apps/details?id=com.jingdong.app.mall |
| bilibili 粉色标识 | https://play.google.com/store/apps/details?id=com.bilibili.app.in （该发行版本带小地球标识） |
| 抖音 | https://apps.apple.com/cn/app/id1142110895，Apple lookup 返回的发行方 artworkUrl512 |
| Google G | https://www.gstatic.com/images/branding/googleg/1x/googleg_standard_color_128dp.png |
| GitHub | https://github.com/favicon.ico，保留透明通道 |

其余图标沿用之前已记录的素材。下载资源仅做 PNG 格式转换，不生成或重绘品牌标识。

## 实际验证

- KulaCore 的 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `xcodegen generate` 与 README 的 Debug xcodebuild 命令：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --command-icons`：通过，八个网站指令的原生输入、空格消费、资产加载、结果匹配及空内容退格在两种外观下均通过；终端模式继续通过。
- 原生设置回归使用独立 TransparentIconsSettingsRegression.app 输出副本：通过，输出 `Settings native light/dark snapshots passed`。
- 检查最新原生设置浅色/深色截图及 `build/transparent-command-icons-contact-sheet.png`：没有附加白色底板，品牌底色、透明留白、视觉尺寸、圆角与搜索框显示正常。
- 日志位于 `build/transparent-command-icons-{swift,build,launcher,settings}.log`；临时脚本、截图、测试 App 继续由已有 build/ 忽略规则覆盖。
- README 中英文同步透明留白说明；AGENTS.md unchanged，无开发规则、模块边界或入口变化。未打包 Release 或安装 App。
