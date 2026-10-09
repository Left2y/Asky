import { defineTool, type ToolDefinition } from "@earendil-works/pi-coding-agent";
import { Type, type TSchema } from "typebox";
import { describeResult, type NativeBridge } from "../bridge.js";
import type { JSONValue, WireToolDefinition } from "../protocol.js";

/** Per-session hooks every extension receives. */
export interface ExtensionContext {
  bridge: NativeBridge;
  /** Task currently running in this session (one task per session). */
  currentTask(): string | undefined;
  /** Ends the current turn without a model reply (used by clarification). */
  endTurn(): void;
  emitClarification(taskID: string, question: string): void;
}

export interface KulaExtension {
  name: string;
  /** Tools this extension owns, chosen from the native catalogue sent in `configure`. */
  tools(catalogue: WireToolDefinition[], ctx: ExtensionContext): ToolDefinition[];
  promptGuidelines: string[];
}

export const USER_REQUESTED = "userRequested";

/**
 * Wraps a native tool. Write tools gain a `userRequested` flag that the model sets only for operations the user
 * explicitly asked for in this turn; it is stripped before forwarding and only maps to the native `intent`.
 * The native ToolService still applies its own confirmation policy and never trusts any "confirmed" field.
 */
export function forwardTool(def: WireToolDefinition, ctx: ExtensionContext): ToolDefinition {
  const schema = structuredClone(def.inputSchema) as Record<string, JSONValue>;
  if (def.effect === "write") {
    const props = (schema.properties ?? {}) as Record<string, JSONValue>;
    props[USER_REQUESTED] = {
      type: "boolean",
      description: "仅当用户在本轮消息中明确要求执行此操作时为 true；由你推断出的操作必须为 false",
    };
    schema.properties = props;
  }
  return defineTool({
    name: def.name,
    label: def.name,
    description: def.summary,
    parameters: Type.Unsafe<Record<string, unknown>>(schema as TSchema),
    executionMode: def.effect === "write" ? "sequential" : undefined,
    async execute(_id, params, signal) {
      const taskID = ctx.currentTask();
      if (!taskID) throw new Error("no active task");
      const args = { ...(params as Record<string, JSONValue>) };
      const explicit = def.effect === "write" && args[USER_REQUESTED] === true;
      delete args[USER_REQUESTED];
      const r = await ctx.bridge.call(taskID, def.name, args, explicit, signal);
      return { content: [{ type: "text", text: describeResult(r) }], details: { status: r.status } };
    },
  });
}
