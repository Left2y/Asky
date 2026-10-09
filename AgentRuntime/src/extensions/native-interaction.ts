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
  promptGuidelines: ["需要澄清时调用 ask_user，而不是在回复中猜测。"],
};
