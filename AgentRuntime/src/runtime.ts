import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import { basename, dirname, join, sep } from "node:path";
import { fileURLToPath } from "node:url";
import {
  createAgentSession,
  ModelRuntime,
  SessionManager,
  SettingsManager,
  type AgentSession,
} from "@earendil-works/pi-coding-agent";
import { NativeBridge } from "./bridge.js";
import { formatContext } from "./extensions/personal-context.js";
import type { ExtensionContext } from "./extensions/types.js";
import { buildTools, whitelistLoader } from "./loader.js";
import {
  encodeFrame,
  LineReader,
  parseHostMessage,
  PROTOCOL_VERSION,
  type AgentRequest,
  type HostMessage,
  type RuntimeMessage,
  type WireToolDefinition,
} from "./protocol.js";

const PROVIDER = "kula";
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;
const MAX_TEXT_ATTACHMENT = 64 * 1024;

interface Configured {
  modelRuntime: ModelRuntime;
  modelID: string;
  tools: WireToolDefinition[];
  pluginGuidance: string[];
}

interface SessionSlot {
  session: AgentSession;
  resourceKey: string;
  taskID?: string;
  cancelled: boolean;
  clarified: boolean;
  lastText: string;
  lastError?: string;
}

function piVersion(): string {
  try {
    const entry = fileURLToPath(import.meta.resolve("@earendil-works/pi-coding-agent"));
    const pkg = JSON.parse(readFileSync(join(dirname(entry), "..", "package.json"), "utf8")) as { version: string };
    return pkg.version;
  } catch {
    return "unknown";
  }
}

export class Runtime {
  private readonly bridge: NativeBridge;
  private configured?: Configured;
  private readonly sessions = new Map<string, SessionSlot>();
  private readonly sessionDir: string;
  private stopping = false;
  /** `configure` is async; prompts sent right after it must wait for it (the host does not await an ack). */
  private configuring: Promise<void> = Promise.resolve();
  /** Cancels that arrived before their prompt started (e.g. while the session was still opening). */
  private readonly earlyCancels = new Set<string>();

  constructor(private readonly writeLine: (line: string) => boolean, private readonly dataDir: string, private readonly agentDir: string) {
    this.bridge = new NativeBridge((m) => this.send(m));
    this.sessionDir = join(agentDir, "sessions");
  }

  start(): void {
    const reader = new LineReader(
      (line) => void this.onLine(line),
      () => this.send({ type: "error", message: "oversized frame dropped" }),
    );
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (c: string) => reader.push(c));
    // Parent gone or closed our input: never linger as an orphan.
    process.stdin.on("end", () => void this.shutdown());
    process.on("SIGTERM", () => void this.shutdown());
    process.on("unhandledRejection", (e) => console.error("[runtime] unhandled", e));
  }

  private send(m: RuntimeMessage): void {
    this.writeLine(encodeFrame(m));
  }

  private async onLine(line: string): Promise<void> {
    const m = parseHostMessage(line);
    if (!m) return this.send({ type: "error", message: "malformed frame" });
    try {
      await this.handle(m);
    } catch (e) {
      this.send({ type: "error", taskID: m.type === "prompt" ? m.request.taskID : undefined, message: String((e as Error)?.message ?? e) });
      if (m.type === "prompt") this.send({ type: "taskState", taskID: m.request.taskID, state: "failed" });
    }
  }

  private async handle(m: HostMessage): Promise<void> {
    switch (m.type) {
      case "hello":
        if (m.protocol !== PROTOCOL_VERSION) { this.send({ type: "error", message: "protocol mismatch" }); return; }
        this.send({ type: "ready", protocol: PROTOCOL_VERSION, runtime: `asky-agent-runtime/0.1.0 pi/${piVersion()} node/${process.versions.node}` });
        return;
      case "configure": {
        const next = this.configuring.then(() => this.configure(m));
        this.configuring = next.catch(() => {});
        await next;
        return;
      }
      case "resources":
        await this.configuring;
        if (this.configured) Object.assign(this.configured, { tools: m.tools, pluginGuidance: m.pluginGuidance });
        return;
      case "prompt":
        await this.prompt(m.request, m.sessionFile);
        return;
      case "cancel":
        this.cancel(m.taskID);
        return;
      case "toolResult":
        this.bridge.resolve(m.callID, m.result);
        return;
      case "shutdown":
        await this.shutdown();
        return;
    }
  }

  private async configure(m: Extract<HostMessage, { type: "configure" }>): Promise<void> {
    const modelRuntime = await ModelRuntime.create({
      authPath: join(this.agentDir, "auth.json"),
      modelsPath: join(this.agentDir, "models.json"),
    });
    modelRuntime.registerProvider(PROVIDER, {
      name: "Asky",
      baseUrl: m.baseURL,
      api: "openai-completions",
      models: [{
        id: m.model, name: m.model, input: ["text", "image"], reasoning: false,
        contextWindow: 128_000, maxTokens: 8192, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      }],
    });
    // In-memory only: never written to auth.json.
    await modelRuntime.setRuntimeApiKey(PROVIDER, m.apiKey);
    for (const slot of this.sessions.values()) slot.session.dispose();
    this.sessions.clear();
    this.configured = { modelRuntime, modelID: m.model, tools: m.tools, pluginGuidance: m.pluginGuidance ?? [] };
  }

  /** Only session files inside our own session directory may be reopened. */
  private safeSessionFile(path?: string): string | undefined {
    if (!path || !existsSync(path)) return undefined;
    const real = realpathSync(path), root = realpathSync(this.sessionDir);
    return real.startsWith(root + sep) && statSync(real).isFile() ? real : undefined;
  }

  private async openSession(sessionID: string, sessionFile?: string): Promise<SessionSlot> {
    const cfg = this.configured;
    if (!cfg) throw new Error("runtime not configured");
    const model = cfg.modelRuntime.getModel(PROVIDER, cfg.modelID);
    if (!model) throw new Error("model not registered");
    const file = this.safeSessionFile(sessionFile);
    const sessionManager = file ? SessionManager.open(file, this.sessionDir) : SessionManager.create(this.dataDir, this.sessionDir);

    const slot = { resourceKey: JSON.stringify([cfg.tools, cfg.pluginGuidance]), cancelled: false, clarified: false, lastText: "" } as SessionSlot;
    const ctx: ExtensionContext = {
      bridge: this.bridge,
      currentTask: () => slot.taskID,
      endTurn: () => void slot.session.abort(),
      emitClarification: (taskID, question) => {
        slot.clarified = true;
        this.send({ type: "clarification", taskID, question });
      },
    };
    const customTools = buildTools(cfg.tools, ctx);
    const { session } = await createAgentSession({
      cwd: this.dataDir,
      agentDir: this.agentDir,
      model,
      thinkingLevel: "off",
      modelRuntime: cfg.modelRuntime,
      resourceLoader: whitelistLoader(cfg.pluginGuidance),
      noTools: "builtin",
      tools: customTools.map((t) => t.name),
      customTools,
      sessionManager,
      settingsManager: SettingsManager.inMemory({
        retry: { enabled: true, maxRetries: 1 },
        enableInstallTelemetry: false,
      }),
    });
    slot.session = session;
    session.subscribe((ev) => {
      const taskID = slot.taskID;
      if (!taskID) return;
      if (ev.type === "message_update" && ev.assistantMessageEvent.type === "text_delta") {
        this.send({ type: "textDelta", taskID, text: ev.assistantMessageEvent.delta });
      } else if (ev.type === "message_end" && ev.message.role === "assistant") {
        const msg = ev.message as { content?: { type: string; text?: string }[]; stopReason?: string; errorMessage?: string };
        slot.lastText = (msg.content ?? []).filter((c) => c.type === "text").map((c) => c.text ?? "").join("");
        slot.lastError = msg.stopReason === "error" ? (msg.errorMessage ?? "model error") : undefined;
      }
    });
    this.sessions.set(sessionID, slot);
    return slot;
  }

  private async prompt(req: AgentRequest, sessionFile?: string): Promise<void> {
    await this.configuring;
    let slot = this.sessions.get(req.sessionID);
    const resourceKey = JSON.stringify([this.configured?.tools, this.configured?.pluginGuidance]);
    if (slot && !slot.taskID && slot.resourceKey !== resourceKey) {
      sessionFile ??= slot.session.sessionFile;
      slot.session.dispose(); this.sessions.delete(req.sessionID); slot = undefined;
    }
    if (slot?.taskID) {
      this.send({ type: "error", taskID: req.taskID, message: "该会话已有任务在运行" });
      this.send({ type: "taskState", taskID: req.taskID, state: "failed" });
      return;
    }
    if (!slot) {
      await this.configuring;
      slot = this.sessions.get(req.sessionID) ?? (await this.openSession(req.sessionID, sessionFile));
    }
    if (this.earlyCancels.delete(req.taskID)) return this.send({ type: "taskState", taskID: req.taskID, state: "cancelled" });
    Object.assign(slot, { taskID: req.taskID, cancelled: false, clarified: false, lastText: "", lastError: undefined });
    this.send({ type: "taskState", taskID: req.taskID, state: "running" });

    const { text, images } = this.composeInput(req);
    let thrown: string | undefined;
    try {
      await slot.session.prompt(text, { images, expandPromptTemplates: false });
    } catch (e) {
      thrown = String((e as Error)?.message ?? e);
    }
    const taskID = req.taskID;
    slot.taskID = undefined;
    const sessionFileOut = slot.session.sessionFile;
    if (slot.cancelled) return this.send({ type: "taskState", taskID, state: "cancelled", sessionFile: sessionFileOut });
    if (slot.clarified) return this.send({ type: "taskState", taskID, state: "awaitingInput", sessionFile: sessionFileOut });
    const err = thrown ?? slot.lastError;
    if (err) {
      this.send({ type: "error", taskID, message: err });
      return this.send({ type: "taskState", taskID, state: "failed", sessionFile: sessionFileOut });
    }
    this.send({ type: "message", taskID, text: slot.lastText });
    this.send({ type: "taskState", taskID, state: "completed", sessionFile: sessionFileOut });
  }

  /** Attachments arrive by path; images are read once here, text attachments are bounded. */
  private composeInput(req: AgentRequest): { text: string; images: { type: "image"; data: string; mimeType: string }[] } {
    const images: { type: "image"; data: string; mimeType: string }[] = [];
    const blocks: string[] = [];
    for (const a of req.attachments) {
      try {
        if (a.kind === "image" && a.byteSize <= MAX_IMAGE_BYTES) {
          images.push({ type: "image", data: readFileSync(a.path).toString("base64"), mimeType: a.mimeType });
        } else if (a.kind === "text") {
          const t = readFileSync(a.path, "utf8").slice(0, MAX_TEXT_ATTACHMENT);
          blocks.push(`<attachment name="${basename(a.path).replaceAll('"', "'")}">\n${t}\n</attachment>`);
        }
      } catch {
        blocks.push(`<attachment name="${basename(a.path)}">（无法读取）</attachment>`);
      }
    }
    const att = blocks.length ? blocks.join("\n") + "\n\n" : "";
    return { text: formatContext(req.context) + att + req.text, images };
  }

  private cancel(taskID: string): void {
    const slot = [...this.sessions.values()].find((s) => s.taskID === taskID);
    if (!slot) {
      if (this.earlyCancels.size < 64) this.earlyCancels.add(taskID);
      return;
    }
    slot.cancelled = true;
    this.bridge.cancelTask(taskID);
    void slot.session.abort();
  }

  private async shutdown(): Promise<void> {
    if (this.stopping) return;
    this.stopping = true;
    for (const slot of this.sessions.values()) {
      if (slot.taskID) {
        slot.cancelled = true;
        this.bridge.cancelTask(slot.taskID);
        await slot.session.abort().catch(() => {});
      }
      slot.session.dispose();
    }
    this.sessions.clear();
    process.stdout.once("drain", () => process.exit(0));
    setImmediate(() => process.exit(0));
  }
}
