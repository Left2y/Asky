import { forwardTool, type KulaExtension } from "./types.js";

/** Calendar, reminders, notes, contacts, Chrome, Messages drafts, Shortcuts — all forwarded to the native ToolService. */
export const systemTools: KulaExtension = {
  name: "system-tools",
  tools(catalogue, ctx) {
    return catalogue.filter((t) => t.agentExposable && t.source !== "memory").map((t) => forwardTool(t, ctx));
  },
  promptGuidelines: [
    "只能通过提供的工具读写系统数据；不存在发送消息或执行 Shell 的能力。",
    "只有工具结果 status 为 completed 时才能说操作已完成；suggestion/rejected/cancelled/failed 表示未执行，pendingVerification 表示需要用户核实，不得重试写入。",
    "创建日程前先调用 calendar_list_calendars，使用实际日历 ID。用户已指定目标则按其选择；否则优先可写默认日历，或唯一可写日历；多个可写候选且无可写默认时必须请用户选择，不得猜日历名称。没有可写日历时说明需在系统日历中启用账户或创建日历。",
    "修改、删除和交接操作会由用户在原生界面确认，你不能替用户确认。",
  ],
};
