# 启动器“更多”按钮原位变形

日期：2026-10-18。

## 实现

- macOS 26+ 开启液态玻璃时，按钮与菜单在同一 `GlassEffectContainer` 内使用相同 `glassEffectID` 和 `.matchedGeometry` 过渡；菜单向左上方展开，右下角始终对齐原按钮。
- 展开、收回均使用 180 ms 的 smooth 动画，按本次反馈从 280 ms 加快。开启“减少动态效果”时立即切换；旧系统或关闭液态玻璃时保留现有材质回退。
- 删除启动器原来的独立更多菜单子窗口。菜单高度受主窗口约束，内容过多时内部滚动；主窗口不为菜单改变尺寸。
- 展开时暂停底层结果行的悬停选中；展开、收回时记录当前指针位置，避免变形揭露底层结果后意外改变目标。
- 点击菜单以外区域关闭菜单；菜单内滚轮交给菜单，避免滚动底层结果。保留原有键盘导航和执行逻辑。

## 已实际执行

1. `xcodegen generate`：通过。
2. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/MoreMorphDerivedData build`：最终 180 ms 版本构建通过，日志 `build/morph-build-final.log`。
3. 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，日志 `build/morph-core-tests.log`。
4. `python3 App/Tests/check-localization.py`：通过，日志 `build/morph-localization.log`。
5. 真实 `LauncherPanel` / `LauncherView` 回归，浅色与深色均通过：⌘K 切换、方向键选动作、回车复制文件和路径、Esc 关闭、保留输入焦点与搜索词、外壳尺寸不变、无更多菜单子窗口，以及原有应用、末行、AI 和计算分支。
6. 经 `orca computer` 对前台原生窗口执行 More 按钮的 `AXPress`，回读从关闭按钮变为菜单项；搜索词仍为 `Design`，焦点仍在搜索输入框。坐标点击因非激活面板没有系统焦点而被工具拒绝，未将其记为通过。
7. 查看浅色及深色截图、录屏抽帧，确认按钮原位扩大为菜单并缩回，菜单不越过主窗口边界。180 ms 深色录屏另导出 `build/launcher-more-fast.gif` 便于查看。

原生回归的实际命令：

```sh
ASKY_DERIVED_DATA=/Users/niallyoung/orca/Asky/build/MoreMorphDerivedData \
  python3 build/MoreMorphSourceSnapshot/App/Tests/run-launcher-window-regression.py --action-bar --more-motion
```

并行任务持续更新共享构建产物和剪贴板源码，最初出现 Swift 编译输入被修改的错误。本次改用独立 DerivedData 与 `build/MoreMorphSourceSnapshot` 源码副本；最终四个任务 Swift 文件逐字节核对与受测副本一致。最终回归日志为 `build/morph-regression-fast.log`，含两种外观的通过结果与录屏路径。录屏使用唯一文件名以支持重复运行，并在录制后恢复测试面板的 key 状态。

## 边界与文件维护

- macOS 15 实机、降低透明度、增强对比度及开启减少动态效果的实机表现未单独运行验证；仅保留对应代码路径，不记为已通过。
- `README: updated`：同步中英文交互说明与原生回归命令。
- `AGENTS.md: unchanged`：现有 App 边界、构建与原生验证要求仍适用。
- 构建、截图、录屏、日志、源码副本及 GIF 沿用现有 `build/` 忽略规则；未添加忽略规则。并行的剪贴板、图标及其文档改动不属于本次提交。
