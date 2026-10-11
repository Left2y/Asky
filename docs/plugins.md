# GitHub 插件

Asky 插件是用户主动安装的可信本机代码。主应用携带插件宿主，不携带官方插件实现；官方与自行安装的插件使用同一套安装和执行接口。官方插件各自拥有独立仓库，首个为 [Orca](https://github.com/Niall-Young/asky-plugin-orca)。不提供系统沙箱，也不宣称能力声明能限制插件自行执行的代码。

## 安装与生命周期

设置 › 插件可安装官方插件或添加公开 GitHub HTTPS 仓库根目录链接。清单必须位于默认分支根目录。首版不支持私有仓库认证、子目录安装或 Pi 扩展直接兼容。

安装需要 Git。插件存放在现有应用数据根目录的 `plugins/<id>/`；配置、来源、commit、启用状态和运行状态保存在 LocalStore。安装时一次说明本机代码执行能力；安装完成默认启用，缺少必填配置时不提供工具。不会自动安装任何插件。

插件提供可直接运行的 JS/ESM 入口；不执行构建命令。有运行依赖时要求 package-lock.json 和本机 npm，执行 `npm ci --omit=dev --ignore-scripts --no-audit --no-fund`。首版不支持需要安装脚本的依赖。Orca 无 npm 依赖，使用 Asky 的随包 Node。

下载、清单检查和依赖安装在临时目录完成后切换。更新由用户触发，失败保留旧版本，成功后保留一个旧版供回退。执行期间固定版本与配置，更新/卸载等待该插件的调用和回读结束。停用立即阻止后续调用；工具与指导在下一次 AI 请求刷新，不取消其他会话。

卸载删除安装和配置，保留历史执行记录与交接状态，不删除外部工作区或终止外部 Agent。重新安装相同 ID 可继续查询旧交接。

官方身份由应用的精确来源清单判定，不信任插件自行声明。加入官方清单需要主项目变更；插件自身更新不要求更新 Asky。

## API v1

仓库包含 `asky-plugin.json`、JS/ESM 入口和可选操作指导。参考最小结构：

```json
{
  "id": "example",
  "name": "Example",
  "version": "0.1.0",
  "apiVersion": 1,
  "entry": "index.mjs",
  "instructions": "SKILL.md",
  "configuration": [
    {"key": "cli_path", "label": "CLI", "type": "path", "defaultValue": "example"}
  ],
  "tools": [{
    "name": "status",
    "description": "查询 Example 状态",
    "effect": "read",
    "confirmation": "never",
    "timeoutSeconds": 20,
    "inputSchema": {"type": "object", "properties": {}, "additionalProperties": false}
  }]
}
```

ID、工具名、配置 key 使用小写字母开头、字母/数字/下划线/短横线，最长 64 字符。配置支持 text、path、boolean、enum，字段可声明 required、defaultValue 和 options。工具名对模型显示为 `plugin_<id>__<tool>`，不能覆盖内置工具。

工具参数支持 JSON Schema 的基本 type、required、properties、additionalProperties、enum、minLength 和数组 items 检查，不提供完整 JSON Schema 方言实现。入口与指导必须为插件目录内的普通文件；清单最多 128 KiB，指导最多 64 KiB。

工具 effect 为 read 或 write。read 使用 never；write 使用 always、createDirectOtherwiseConfirm 或 explicitDirectOtherwiseConfirm。最后一种允许用户明确要求的插件任务直接执行，AI 自行推断的写操作仍只作为建议。首版写工具按 handoff 分类，所以 createDirectOtherwiseConfirm 会要求确认。

```js
export default {
  tools: {
    status: {
      async execute(args, context) {
        return await context.exec(context.configuration.cli_path, ['status', '--json']);
      }
    }
  }
};
```

宿主上下文：

- `configuration`：本次调用固定的配置对象。
- `signal`：本次调用的 AbortSignal；取消会终止宿主管理的执行进程。
- `requestID`：原生稳定请求 ID。使用它记录检查点，避免重复产生外部操作。
- `state`：该插件的持久化 JSON 状态快照。
- `await saveState(value)`：通过宿主更新状态；同一插件调用串行执行。
- `await exec(executable, argv, {cwd?, timeoutSeconds?})`：经 ToolService 执行 CLI，返回 stdout、stderr 和 exitCode。以数组传参，不通过 Shell 拼接。默认 20 秒，单次 CLI 上限 120 秒。

写工具同时实现 `async readback(args, context, output)`。output 是执行返回值，超时后可能为 null。回读返回真实已核实结果；无法核实时返回 null，宿主标记 pendingVerification。回读不应重放创建或发送。插件状态落盘与外部操作并非原子事务，必须保存“尝试前”检查点并核实未知结果。

工具调用总超时默认 20 秒，可声明 1–240 秒。CLI 每个输出流和插件协议帧上限 512 KiB；console 输出进入安装目录的 execution.log，调用间将超过 1 MiB 的旧日志清空。取消终止本次插件进程和 CLI 客户端，不撤销已完成操作，也不自动终止外部 Agent。

插件执行进程继承用户 HOME 与常见程序 PATH，不继承模型 API Key。可信代码仍有本机用户权限；独立进程不构成安全隔离。插件工具不向外部 MCP 暴露。

## Orca

Orca 插件默认按明确项目路径添加/复用项目，从项目默认 base 创建独立 worktree，启动指定 Agent，等待就绪并发送 prompt。默认 Agent 为 codex；原目录未提交修改不会复制。返回交接 ID、工作区和 input_accepted / turn_started 等阶段，提交后不监控完成。后续查询和发送消息由用户请求。

首版不提供远程 Orca、模型启动参数、多 Agent 编排、自动合并或发布。真实验收与模拟测试分别记录在 [验证记录](validation/2026-10-11-plugins.md)。
