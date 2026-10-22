import { defineTool } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import type { KulaExtension } from "./types.js";

/**
 * Native interaction: clarification is rendered by SwiftUI. Asking ends the current turn; the user's answer
 * arrives as the next prompt in the same session. Confirmation is deliberately not a tool — only the native
 * ToolService can show and accept confirmations.
 */
export const nativeInteraction: KulaExtension = {
  name: "native-interaction",
  tools(_catalogue, ctx) {
    return [
      defineTool({
        name: "ask_user",
        label: "ask_user",
        description: "当目标、对象或参数不明确时向用户提出一个澄清问题。调用后本轮结束，用户的回答会作为下一条消息到达。",
        parameters: Type.Object({ question: Type.String({ minLength: 1, maxLength: 500 }) }, { additionalProperties: false }),
        executionMode: "sequential",
        async execute(_id, params) {
          const taskID = ctx.currentTask();
          if (taskID) ctx.emitClarification(taskID, params.question);
          ctx.endTurn();
          return { content: [{ type: "text", text: "问题已显示给用户，等待回答。" }], details: {} };
        },
      }),
    ];
  },
  promptGuidelines: [
    "需要用户选择或填写参数时，优先在普通回复中输出一个 asky-form 原生表单，然后结束本轮等待用户提交；只需一句开放问题时使用 ask_user。不要猜测用户选择。",
    '表单使用独立的 ```asky-form 代码围栏；第一行是 JSON 标题，例如 {"title":"会议安排"}；此后每行一个完整 JSON 字段，逐行输出，最后用 ``` 关闭。不要把整个表单放进一个 JSON 对象或数组，不要用 HTML、Swift 代码或 Markdown 表格替代表单。',
    '字段格式：{"id":"duration","type":"select","label":"时长","required":true,"options":["30 分钟","60 分钟"]}。type 仅支持 text（文本）、select（单选）、multi（多选）、date（日期，默认今天，回复 yyyy-MM-dd）、time（时刻，默认时分）、duration（时长，默认分秒，初值为零）；text/date/time/duration 不带 options。time/duration 可用 components 按需指定 ["hour","minute","second"] 的非空有序子集，不要显示不需要的单位。具体时刻（如 14:30、会议开始时间）必须使用 time；倒计时、运动/音频时长使用 duration，不能用 text 让用户手输。时分秒用 components:["hour","minute","second"]，只要分秒用 ["minute","second"]，也可仅分钟或仅秒钟。值按所选单位顺序以冒号分隔、各段两位；time 的小时 00–23、分秒 00–59，duration 首段 00–99、其余 00–59。duration 的用户回复会带明确单位，不当成钟点。上午/下午等时间段选项仍可用 select。',
    "每条回复最多一个表单，标题不超过 120 字、最多 16 个字段、字段 id 唯一且不超过 64 字、label 不超过 200 字、每个选择字段 1–20 个不重复选项且每项不超过 200 字。required 可省略，默认选填。先输出简短说明，再尽早逐行输出字段，不要在表单后继续调用工具或 ask_user。",
    "表单只收集普通信息，不请求密码或 API Key。提交内容是用户补充信息，不代表系统操作确认；任何实际操作仍需走原生工具及其权限和确认规则。用户也可以直接输入文字回答，不必强制填写表单。讨论代码示例时将 asky-form 示例包在四个反引号围栏内，避免生成可操作表单。",
  ],
};
