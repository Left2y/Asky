// JSONL wire protocol v2 — mirror of Packages/KulaCore/Sources/AgentHost/WireProtocol.swift.
// stdout carries protocol frames only; all diagnostics go to stderr.

export const PROTOCOL_VERSION = 2;
export const MAX_FRAME_BYTES = 1 << 20;

export type JSONValue = null | boolean | number | string | JSONValue[] | { [k: string]: JSONValue };

export interface WireToolDefinition {
  name: string;
  summary: string;
  inputSchema: { [k: string]: JSONValue };
  source: string;
  effect: "read" | "write";
  writeKind?: string;
  confirmation: string;
  externallyExposable: boolean;
  agentExposable: boolean;
}

export interface AttachmentRef {
  id: string;
  kind: "image" | "text" | "file";
  path: string;
  mimeType: string;
  byteSize: number;
  temporary: boolean;
}

export interface AgentRequest {
  sessionID: string;
  taskID: string;
  text: string;
  attachments: AttachmentRef[];
  context: { sourceID: string; text: string }[];
}

export interface ExecutionResult {
  requestID: string;
  status: string;
  targets?: { kind: string; identifier: string }[];
  output?: JSONValue;
  readback?: JSONValue;
  error?: { code: string; message: string };
  confirmation?: JSONValue;
}

export type HostMessage =
  | { type: "hello"; protocol: number }
  | { type: "configure"; baseURL: string; model: string; apiKey: string; tools: WireToolDefinition[]; maxToolRounds: number; pluginGuidance?: string[] }
  | { type: "resources"; tools: WireToolDefinition[]; pluginGuidance: string[] }
  | { type: "prompt"; request: AgentRequest; sessionFile?: string }
  | { type: "cancel"; taskID: string }
  | { type: "toolResult"; callID: string; result: ExecutionResult }
  | { type: "shutdown" };

export type TaskState =
  | "starting" | "running" | "compacting" | "awaitingInput" | "awaitingConfirmation"
  | "completed" | "cancelled" | "failed" | "pendingVerification";

export type RuntimeMessage =
  | { type: "ready"; protocol: number; runtime: string }
  | { type: "taskState"; taskID: string; state: TaskState; sessionFile?: string }
  | { type: "textDelta"; taskID: string; text: string }
  | { type: "message"; taskID: string; text: string }
  | { type: "toolCall"; taskID: string; callID: string; tool: string; arguments: JSONValue; intent: "explicitRequest" | "aiSuggested" }
  | { type: "clarification"; taskID: string; question: string }
  | { type: "error"; taskID?: string; message: string };

export type FrameWriter = (msg: RuntimeMessage) => void;

/** Serialises one frame. Oversized frames are replaced by an error frame rather than split. */
export function encodeFrame(msg: RuntimeMessage): string {
  const line = JSON.stringify(msg);
  if (Buffer.byteLength(line, "utf8") >= MAX_FRAME_BYTES) {
    const taskID = "taskID" in msg ? msg.taskID : undefined;
    return JSON.stringify({ type: "error", taskID, message: `frame too large (${msg.type})` }) + "\n";
  }
  return line + "\n";
}

/** Splits stdin into frames; lines beyond MAX_FRAME_BYTES are dropped up to the next newline. */
export class LineReader {
  private buf = "";
  private discarding = false;
  constructor(private readonly onLine: (line: string) => void, private readonly onOversize: () => void) {}

  push(chunk: string): void {
    let rest = chunk;
    for (;;) {
      const nl = rest.indexOf("\n");
      if (nl < 0) break;
      const part = rest.slice(0, nl);
      rest = rest.slice(nl + 1);
      if (this.discarding) {
        this.discarding = false;
        this.buf = "";
        continue;
      }
      const line = this.buf + part;
      this.buf = "";
      if (Buffer.byteLength(line, "utf8") > MAX_FRAME_BYTES) this.onOversize();
      else if (line.trim().length > 0) this.onLine(line);
    }
    if (!this.discarding) {
      this.buf += rest;
      if (Buffer.byteLength(this.buf, "utf8") > MAX_FRAME_BYTES) {
        this.buf = "";
        this.discarding = true;
        this.onOversize();
      }
    }
  }
}

export function parseHostMessage(line: string): HostMessage | undefined {
  try {
    const v = JSON.parse(line) as { type?: unknown };
    if (typeof v !== "object" || v === null || typeof v.type !== "string") return undefined;
    return v as HostMessage;
  } catch {
    return undefined;
  }
}
