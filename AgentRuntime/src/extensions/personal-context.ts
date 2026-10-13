import { forwardTool, type KulaExtension } from "./types.js";

/** Authorised personal memory: the MEMORY.md index arrives as context, topic files are read with `memory_read`; writes follow native confirmation policy. */
export const personalContext: KulaExtension = {
  name: "personal-context",
  tools(catalogue, ctx) {
    return catalogue.filter((t) => t.agentExposable && t.source === "memory").map((t) => forwardTool(t, ctx));
  },
  promptGuidelines: [
    "source 为 memory/MEMORY.md 的 <context> 是用户授权的个人记忆索引；需要某个主题的细节时，用 memory_read 读取索引「主题文件」下列出的文件，不要猜测其中内容。",
    "称呼与联系人对应关系不明确时先询问，不要擅自绑定。",
    "用户明确要求记住某事（如“记住…”“以后…”“请记下我喜欢…”）时调用 memory_save，内容写成以“用户”为主语的一句完整陈述；不要保存密码、验证码、证件号等敏感信息。",
    "简短的身份事实和偏好写入 MEMORY.md（section 为 关于我 或 偏好）；某个主题的细节写入主题文件（file 如 projects.md，新文件需给 description）。",
    "用户纠正或要求忘记已有记忆时，用 memory_correct 或 memory_forget，file 填所在文件，old 填文件中原样出现的文字；主题文件的内容先用 memory_read 读取再改。",
    "只有 memory_save 等工具返回成功后才能说“已记住”；不要声称记住了未保存的内容。",
  ],
};

/** Formats native-assembled context snippets with provenance. */
export function formatContext(snippets: { sourceID: string; text: string }[]): string {
  if (snippets.length === 0) return "";
  const esc = (s: string) => s.replaceAll("</context>", "<\\/context>");
  return snippets.map((s) => `<context source="${esc(s.sourceID).replaceAll('"', "'")}">\n${esc(s.text)}\n</context>`).join("\n") + "\n\n";
}
