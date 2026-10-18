# 市制“两”换算验证

- 补充质量单位“两”，按市制 1 两 = 0.05 千克，1 斤 = 10 两。
- 数字前缀仅接收 ASCII 数字，避免 `Character.isNumber` 将“两”当作数字吞入数值。
- 回归用例覆盖 `1斤转两`、`10两换成斤`、`1 两 克`、`50 g to 两`、`0.5两 克`、`1 公斤 两`，以及展示文本和不兼容维度拒绝。

实际执行：

```sh
cd Packages/KulaCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

结果：通过，退出码 0，包含 ConversionTests 与其余 KulaCore 测试目标。未修改 App 代码，未执行 App 构建或原生窗口验收。

README 与 AGENTS.md 无需修改：本次补全现有质量换算，不改变开发命令、模块边界或使用方式。保留工作区原有剪贴板相关改动。
