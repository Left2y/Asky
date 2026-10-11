# 模型设置按钮反馈

- 保存与配置检查成功后，按钮内显示勾号，1.5 秒后恢复原标签。
- 使用原标签保留按钮尺寸，反馈以 overlay 显示；保存中与检查中也在按钮内反馈，不新增独立进度控件。
- 删除“已保存。”“检查完成。”列表提示行；保留实际错误提示，下一次操作时清除旧错误。
- 反馈定时任务跟随视图生命周期取消，执行中及短暂反馈期间避免重复点击。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-settings-regression.py`：原生浅深色页面渲染、导航及最小尺寸检查通过；查看本轮浅色模型设置截图。
- 本轮没有使用真实 API Key 执行保存或网络能力检查；成功反馈的触发、复原与固定尺寸通过代码检查，原生回归不覆盖这两个操作的成功路径。

README: unchanged — 使用流程、命令与功能范围不变。
AGENTS.md: unchanged — 开发入口和架构边界不变。
截图与回归程序沿用 `build/` 忽略规则，未打包或安装 Release。
