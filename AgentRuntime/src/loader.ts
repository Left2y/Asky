import { createExtensionRuntime, type ResourceLoader, type ToolDefinition } from "@earendil-works/pi-coding-agent";
import { nativeInteraction } from "./extensions/native-interaction.js";
import { personalContext } from "./extensions/personal-context.js";
import { systemTools } from "./extensions/system-tools.js";
import type { ExtensionContext, KulaExtension } from "./extensions/types.js";
import type { WireToolDefinition } from "./protocol.js";

/** The only extensions that can ever load. No file discovery, no skills, prompts, themes or AGENTS files. */
export const EXTENSION_WHITELIST: readonly KulaExtension[] = [systemTools, personalContext, nativeInteraction];

export function buildTools(catalogue: WireToolDefinition[], ctx: ExtensionContext): ToolDefinition[] {
  const seen = new Set<string>();
  const out: ToolDefinition[] = [];
  for (const ext of EXTENSION_WHITELIST) {
    for (const t of ext.tools(catalogue, ctx)) {
      if (seen.has(t.name)) continue;
      seen.add(t.name);
      out.push(t);
    }
  }
  return out;
}

export function systemPrompt(now: Date = new Date()): string {
  const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
  const lines = EXTENSION_WHITELIST.flatMap((e) => e.promptGuidelines);
  return [
    "你是 KulaHere，macOS 上的个人助理。用简洁的中文回答。",
    `当前本地时间：${now.toString()}（时区 ${tz}）。日期时间参数使用 ISO 8601 并带时区偏移。`,
    "回复使用 Markdown。最多使用一层标题：需要标题时统一使用 ###，不要使用 #、##、其他级别或嵌套标题；简短回复无需标题。",
    "规则：",
    ...lines.map((l) => `- ${l}`),
  ].join("\n");
}

/** Fully host-owned resource loader: nothing is read from ~/.pi or the working directory. */
export function whitelistLoader(): ResourceLoader {
  return {
    getExtensions: () => ({ extensions: [], errors: [], runtime: createExtensionRuntime() }),
    getSkills: () => ({ skills: [], diagnostics: [] }),
    getPrompts: () => ({ prompts: [], diagnostics: [] }),
    getThemes: () => ({ themes: [], diagnostics: [] }),
    getAgentsFiles: () => ({ agentsFiles: [] }),
    getSystemPrompt: () => systemPrompt(),
    getSystemPromptSource: () => undefined,
    getAppendSystemPrompt: () => [],
    getAppendSystemPromptSources: () => [],
    extendResources: () => {},
    reload: async () => {},
  };
}
