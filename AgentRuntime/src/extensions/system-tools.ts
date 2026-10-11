import { forwardTool, type KulaExtension } from "./types.js";

/** Calendar, reminders, notes, contacts, Chrome, Messages drafts, Shortcuts — all forwarded to the native ToolService. */
export const systemTools: KulaExtension = {
  name: "system-tools",
  tools(catalogue, ctx) {
    return catalogue.filter((t) => t.agentExposable && t.source !== "memory").map((t) => forwardTool(t, ctx));
  },
  promptGuidelines: [
    "只能通过提供的工具读写系统数据；内置工具不提供自由 Shell 或发送消息的能力；已启用插件可以提供其声明的 CLI 操作。",
    "日程、提醒事项、备忘录、通讯录和短信只使用 macOS 苹果官方应用与接口：苹果日历（EventKit）、提醒事项（EventKit）、备忘录（Notes）、通讯录（Contacts）、信息（Messages）。不得推荐或声称使用第三方替代工具。短信只准备草稿，由用户在信息中发送。",
    "日历结果中的 application 表示应用，calendar/name 表示苹果日历内的日历名称，account 表示账户，三者不能混淆。即使日历名叫「大麦」，也不是大麦应用。创建结果应写成「已在苹果日历创建；所属日历：〈工具返回的真实名称〉」，不得隐藏或改写实际目标；仅在本次查询 isDefault 为 true 时称其为系统默认日历。历史对话与记忆不能覆盖本次工具返回的应用和日历信息。",
    "只有工具结果 status 为 completed 时才能说操作已完成；suggestion/rejected/cancelled/failed 表示未执行，pendingVerification 表示需要用户核实，不得重试写入。",
    "创建日程前先调用 calendar_list_calendars，使用实际日历 ID。用户已指定目标则按其选择；否则优先可写默认日历，或唯一可写日历；多个可写候选且无可写默认时必须请用户选择，不得猜日历名称。没有可写日历时说明需在系统日历中启用账户或创建日历。",
    "内置工具的修改、删除和交接操作由用户在原生界面确认。插件按其声明的规则执行，用户明确要求的插件任务可直接提交；你不能替用户确认。",
  ],
};
