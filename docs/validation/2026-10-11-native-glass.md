# 统一原生玻璃与窗口阴影

## 实现

启动器及固定/筛选按钮、筛选浮层、AI 对话及标题控件、剪贴板主窗口/完整预览、系统授权浮窗/拖拽卡片统一接入 `nativeGlassBackground`。普通模式直接对内容使用原生 Regular 材质，移除黑白底色填充与装饰描边。不使用 Clear 或额外的自制折射、背景截图、磨砂遮罩。

降低透明度和增强对比度均使用不透明主题底色及清晰边框；系统辅助功能环境由共享 modifier 读取。AppKit 嵌入的权限拖拽卡片还显式传递降低透明度状态。

移除玻璃窗口与控件的自绘投影。启动器、剪贴板主窗口/预览、AI 和授权窗口启用 AppKit `hasShadow`；启动器布局更新后调用 `invalidateShadow`。保留原窗口几何与交互，阴影强度由系统决定，不承诺暗色背景下的自定义亮边。

## 检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过，181 项 Swift Testing 测试。
- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild`：最终 `BUILD SUCCEEDED`，日志 `build/native-glass/build-final.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py`：最终浅色/深色通过，窗口高度变化、键盘导航、系统滚动投递、背景不跟随滚动和输入焦点通过，输入漂移 0 pt。第一次执行与视觉探针同时取焦点，系统滚动投递失败；该次不记为通过，停止视觉探针后重跑通过。
- 真实桌面合成截图已查看：启动器浅色收起/深色展开、AI 深色、剪贴板浅色/深色，以及启动器降低透明度、AI 增强对比度的强制分支。浅色使用彩色色块和密集黑字，深色使用暗色块和密集白字；底层字形被磨砂模糊，前景内容清晰。原生阴影沿外形出现，未再出现自绘矩形阴影画布。最终截图为 `build/native-glass/verified-*.png`。
- 实际窗口视觉探针使用生产 SwiftUI 内容与 AppKit 控制器、隔离临时数据库以及独立色块/密集文字背景窗口。辅助功能分支在临时编译副本中强制对应只读环境判断，不修改用户系统设置，不声称已经验收真实设置切换。

截图、临时编译源码和日志均留在已忽略的 `build/native-glass/`。未打包、发布或安装应用。

README: updated，中英文同步原生 Regular、系统阴影及不透明辅助功能回退。AGENTS.md: unchanged，本次未改变模块边界或开发命令。

本轮执行期间启动器、测试和 README 存在另一任务的同步修改与独立提交；无法安全隔离这些文件的完整任务差异，因此本轮不创建混合或不完整的 Git 提交，保留修改供统一检查。
