import { forwardTool, type KulaExtension } from "./types.js";

/** Authorised personal memory: `memory_search` returns natively filtered snippets; memory writes follow native confirmation policy. */
export const personalContext: KulaExtension = {
  name: "personal-context",
  tools(catalogue, ctx) {
    return catalogue.filter((t) => t.agentExposable && t.source === "memory").map((t) => forwardTool(t, ctx));
  },
  promptGuidelines: [
    "<context> 中的内容和 memory_search 结果是用户授权的个人记忆，标注为推测的内容不能当作事实。",
    "称呼与联系人对应关系不明确时先询问，不要擅自绑定。",
    "用户明确要求记住某事（如“记住…”“以后…”“请记下我喜欢…”）时调用 memory_save，内容写成以“用户”为主语的一句完整陈述；不要保存密码、验证码、证件号等敏感信息。",
    "用户纠正或要求忘记已有记忆时，先用 memory_search 找到对应 id，再调用 memory_correct 或 memory_forget。",
    "只有 memory_save 等工具返回成功后才能说“已记住”；不要声称记住了未保存的内容。",
  ],
};

/** Formats native-assembled context snippets with provenance. */
export function formatContext(snippets: { sourceID: string; text: string }[]): string {
  if (snippets.length === 0) return "";
  const esc = (s: string) => s.replaceAll("</context>", "<\\/context>");
  return snippets.map((s) => `<context source="${esc(s.sourceID).replaceAll('"', "'")}">\n${esc(s.text)}\n</context>`).join("\n") + "\n\n";
}
