# 附件卡片间距验证

日期：2026-10-10。

## 修改

按用户截图反馈，将输入区附件卡片可见边缘之间的间距统一为 8 pt（逻辑像素）。移除每张卡片为删除按钮添加的右侧 padding，改为在附件行末尾一次预留 8 pt；顶部仍保留 6 pt。发送后附件行已有 8 pt 间距，保持一致。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：135 项测试、27 个 suite 通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 使用现有回复回归工具的临时副本编译实际 App 源码，在临时数据库窗口展示两张图片和一个文件，检查输入区及已发送附件行。原生窗口截图为 1440 × 1280，scale=2；输入区两张 52 pt 图片横坐标分别为 32、92 pt，文件起点 152 pt，对应间隔均为 8 pt。已发送附件行同样呈现 8 pt 间隔。

截图保留在本地 `build/attachment-spacing-preview.png`，临时预览源码、脚本和可执行文件均在已有忽略目录 `build/` 中，不纳入提交。未调用模型。此次视觉检查覆盖卡片布局；删除按钮的完整交互与滚动末端裁切未单独验收。

## 文档检查

README: unchanged — 微小间距修正不改变已有使用方式、开发命令或能力说明。

AGENTS.md: unchanged — 未改变模块边界、开发流程或持久规则。
