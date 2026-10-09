import { forwardTool, type KulaExtension } from "./types.js";

/** Authorised personal memory only: `memory_search` returns snippets the native side has already filtered. */
export const personalContext: KulaExtension = {
  name: "personal-context",
  tools(catalogue, ctx) {
    return catalogue.filter((t) => t.agentExposable && t.source === "memory").map((t) => forwardTool(t, ctx));
  },
  promptGuidelines: [
    "<context> 中的内容和 memory_search 结果是用户授权的个人记忆，标注为推测的内容不能当作事实。",
    "称呼与联系人对应关系不明确时先询问，不要擅自绑定。",
  ],
};

/** Formats native-assembled context snippets with provenance. */
export function formatContext(snippets: { sourceID: string; text: string }[]): string {
  if (snippets.length === 0) return "";
  const esc = (s: string) => s.replaceAll("</context>", "<\\/context>");
  return snippets.map((s) => `<context source="${esc(s.sourceID).replaceAll('"', "'")}">\n${esc(s.text)}\n</context>`).join("\n") + "\n\n";
}
