// End-to-end: real runtime process + Pi SDK against a local mock OpenAI-compatible endpoint.
import assert from "node:assert/strict";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, readdirSync } from "node:fs";
import { createServer, type IncomingMessage, type Server } from "node:http";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const MAIN = join(dirname(fileURLToPath(import.meta.url)), "..", "src", "main.js");
const KEY = "sk-test-not-a-real-key-123";

type Frame = Record<string, any>;

interface Mock { server: Server; url: string; requests: { auth?: string; body: any }[]; script: ((body: any) => string[])[] }

function sse(chunks: object[]): string[] {
  return [...chunks.map((c) => `data: ${JSON.stringify(c)}\n\n`), "data: [DONE]\n\n"];
}
const base = { id: "c1", object: "chat.completion.chunk", created: 0, model: "mock" };
function toolCallReply(name: string, args: object): string[] {
  return sse([
    { ...base, choices: [{ index: 0, delta: { role: "assistant", tool_calls: [{ index: 0, id: "call_1", type: "function", function: { name, arguments: "" } }] } }] },
    { ...base, choices: [{ index: 0, delta: { tool_calls: [{ index: 0, function: { arguments: JSON.stringify(args) } }] } }] },
    { ...base, choices: [{ index: 0, delta: {}, finish_reason: "tool_calls" }] },
  ]);
}
function textReply(text: string): string[] {
  return sse([
    { ...base, choices: [{ index: 0, delta: { role: "assistant", content: text.slice(0, 2) } }] },
    { ...base, choices: [{ index: 0, delta: { content: text.slice(2) } }] },
    { ...base, choices: [{ index: 0, delta: {}, finish_reason: "stop" }] },
  ]);
}

async function startMock(script: ((body: any) => string[])[]): Promise<Mock> {
  const mock: Mock = { server: undefined as unknown as Server, url: "", requests: [], script };
  mock.server = createServer(async (req: IncomingMessage, res) => {
    let raw = "";
    for await (const c of req) raw += c;
    const body = JSON.parse(raw || "{}");
    mock.requests.push({ auth: req.headers.authorization, body });
    const step = mock.script[Math.min(mock.requests.length - 1, mock.script.length - 1)];
    res.writeHead(200, { "content-type": "text/event-stream" });
    for (const chunk of step(body)) res.write(chunk);
    res.end();
  });
  await new Promise<void>((r) => mock.server.listen(0, "127.0.0.1", r));
  const addr = mock.server.address() as { port: number };
  mock.url = `http://127.0.0.1:${addr.port}/v1`;
  return mock;
}

class Proc {
  frames: Frame[] = [];
  stdoutNoise: string[] = [];
  private waiters: { pred: (f: Frame) => boolean; resolve: (f: Frame) => void }[] = [];
  exit: Promise<number | null>;
  constructor(readonly child: ChildProcessWithoutNullStreams) {
    let buf = "";
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (c: string) => {
      buf += c;
      let nl;
      while ((nl = buf.indexOf("\n")) >= 0) {
        const line = buf.slice(0, nl);
        buf = buf.slice(nl + 1);
        let f: Frame;
        try { f = JSON.parse(line); } catch { this.stdoutNoise.push(line); continue; }
        this.frames.push(f);
        this.waiters = this.waiters.filter((w) => (w.pred(f) ? (w.resolve(f), false) : true));
      }
    });
    child.stderr.resume();
    this.exit = new Promise((r) => child.on("exit", (code) => r(code)));
  }
  send(m: object) { this.child.stdin.write(JSON.stringify(m) + "\n"); }
  next(pred: (f: Frame) => boolean, ms = 10_000): Promise<Frame> {
    const hit = this.frames.find(pred);
    if (hit) return Promise.resolve(hit);
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error(`timeout; frames=${JSON.stringify(this.frames)}`)), ms);
      this.waiters.push({ pred, resolve: (f) => { clearTimeout(t); resolve(f); } });
    });
  }
}

function launch(dataDir: string): Proc {
  // A provider key in the environment must be ignored and scrubbed.
  const child = spawn(process.execPath, [MAIN, "--data-dir", dataDir], {
    env: { PATH: process.env.PATH ?? "", HOME: dataDir, OPENAI_API_KEY: "env-key-must-not-be-used" },
    stdio: ["pipe", "pipe", "pipe"],
  });
  return new Proc(child);
}

const TOOLS = [
  { name: "calendar_create", summary: "新建日程", inputSchema: { type: "object", properties: { title: { type: "string" } }, required: ["title"], additionalProperties: false },
    source: "calendar", effect: "write", writeKind: "create", confirmation: "createDirectOtherwiseConfirm", externallyExposable: true, agentExposable: true },
  { name: "memory_read", summary: "读取记忆主题文件", inputSchema: { type: "object", properties: { file: { type: "string" } }, required: ["file"], additionalProperties: false },
    source: "memory", effect: "read", confirmation: "never", externallyExposable: false, agentExposable: true },
  { name: "hidden_tool", summary: "不应暴露", inputSchema: { type: "object", properties: {}, additionalProperties: false },
    source: "terminal", effect: "read", confirmation: "never", externallyExposable: false, agentExposable: false },
];

async function handshake(p: Proc, mock: Mock, tools: readonly object[] = TOOLS) {
  p.send({ type: "hello", protocol: 2 });
  const ready = await p.next((f) => f.type === "ready");
  assert.equal(ready.protocol, 2);
  assert.match(ready.runtime, /pi\/1\.1\.0/);
  p.send({ type: "configure", baseURL: mock.url, model: "mock-model", apiKey: KEY, tools, maxToolRounds: 8 });
}

const request = (taskID: string, text: string) => ({ sessionID: "s1", taskID, text, attachments: [], context: [{ sourceID: "mem:1", text: "用户偏好早上开会" }] });

test("tool round trip, whitelist, intent mapping and in-memory credential", async () => {
  const mock = await startMock([() => toolCallReply("calendar_create", { title: "牙医", userRequested: true }), () => textReply("已创建日程")]);
  const dataDir = mkdtempSync(join(tmpdir(), "kula-rt-"));
  const p = launch(dataDir);
  try {
    await handshake(p, mock);
    p.send({ type: "prompt", request: request("t1", "明天下午三点加一个牙医日程") });
    await p.next((f) => f.type === "taskState" && f.state === "running");
    const call = await p.next((f) => f.type === "toolCall");
    assert.equal(call.tool, "calendar_create");
    assert.equal(call.intent, "explicitRequest");
    assert.deepEqual(call.arguments, { title: "牙医" });
    p.send({ type: "toolResult", callID: call.callID, result: { requestID: call.callID, status: "completed", targets: [{ kind: "event", identifier: "E1" }], readback: { title: "牙医" } } });
    const msg = await p.next((f) => f.type === "message");
    assert.equal(msg.text, "已创建日程");
    const done = await p.next((f) => f.type === "taskState" && f.state === "completed");
    assert.ok(done.sessionFile && done.sessionFile.startsWith(dataDir) || done.sessionFile?.includes("kula-rt-"));
    assert.ok(p.frames.some((f) => f.type === "textDelta"));

    // Only whitelisted tools reach the model: no read/bash/edit/write, no codemode/tool_search, no hidden tools.
    const names = (mock.requests[0].body.tools ?? []).map((t: any) => t.function.name).sort();
    assert.deepEqual(names, ["ask_user", "calendar_create", "memory_read"]);
    // Credential: injected key used; environment key ignored.
    assert.ok(mock.requests.every((r) => r.auth === `Bearer ${KEY}`));
    // The formatting policy reaches the model through the real runtime.
    const systemMessage = mock.requests[0].body.messages.find((m: any) => m.role === "system");
    assert.ok(systemMessage.content.includes("最多使用一层标题"));
    assert.ok(systemMessage.content.includes("统一使用 ###"));
    // Context snippets are delivered with provenance.
    assert.ok(JSON.stringify(mock.requests[0].body.messages).includes('source=\\"mem:1\\"'));
    // The second request carries the native status text.
    assert.ok(JSON.stringify(mock.requests[1].body.messages).includes("completed"));

    p.send({ type: "shutdown" });
    assert.equal(await p.exit, 0);
    assert.deepEqual(p.stdoutNoise, []);
    // Key never touches disk.
    const files = readdirSync(dataDir, { recursive: true }).map(String).map((f) => join(dataDir, f));
    for (const f of files) {
      try { assert.ok(!readFileSync(f, "utf8").includes(KEY), f); } catch (e) { if ((e as any).code !== "EISDIR") throw e; }
    }
  } finally {
    p.child.kill("SIGKILL");
    mock.server.close();
  }
});

test("ai-suggested writes are flagged and clarification ends the turn", async () => {
  const mock = await startMock([
    () => toolCallReply("calendar_create", { title: "健身" }),
    () => toolCallReply("ask_user", { question: "要提醒哪位奶奶？" }),
    () => textReply("不应到达"),
  ]);
  const dataDir = mkdtempSync(join(tmpdir(), "kula-rt-"));
  const p = launch(dataDir);
  try {
    await handshake(p, mock);
    p.send({ type: "prompt", request: request("t2", "我最近太忙了") });
    const call = await p.next((f) => f.type === "toolCall");
    assert.equal(call.intent, "aiSuggested");
    p.send({ type: "toolResult", callID: call.callID, result: { requestID: call.callID, status: "suggestion" } });
    const q = await p.next((f) => f.type === "clarification");
    assert.equal(q.question, "要提醒哪位奶奶？");
    await p.next((f) => f.type === "taskState" && f.state === "awaitingInput");
    assert.equal(mock.requests.length, 2);
    assert.ok(!p.frames.some((f) => f.type === "taskState" && f.state === "completed"));
  } finally {
    p.child.stdin.end();
    assert.equal(await p.exit, 0);
    mock.server.close();
  }
});

test("cancel while a tool is pending reports cancelled; stdin EOF exits", async () => {
  const mock = await startMock([() => toolCallReply("memory_read", { file: "projects.md" }), () => textReply("不应到达")]);
  const dataDir = mkdtempSync(join(tmpdir(), "kula-rt-"));
  const p = launch(dataDir);
  try {
    await handshake(p, mock);
    p.send({ type: "prompt", request: request("t3", "查一下") });
    await p.next((f) => f.type === "toolCall");
    p.send({ type: "cancel", taskID: "t3" });
    await p.next((f) => f.type === "taskState" && f.state === "cancelled");
    assert.equal(mock.requests.length, 1);
  } finally {
    p.child.stdin.end();
    assert.equal(await p.exit, 0);
    mock.server.close();
  }
});

test("rejects session files outside the runtime session directory", async () => {
  const mock = await startMock([() => textReply("你好")]);
  const dataDir = mkdtempSync(join(tmpdir(), "kula-rt-"));
  const p = launch(dataDir);
  try {
    await handshake(p, mock);
    p.send({ type: "prompt", request: request("t4", "hi"), sessionFile: "/etc/hosts" });
    const done = await p.next((f) => f.type === "taskState" && f.state === "completed");
    assert.notEqual(done.sessionFile, "/etc/hosts");
    assert.ok(existsSync(join(dataDir, "pi", "sessions")));
  } finally {
    p.child.stdin.end();
    await p.exit;
    mock.server.close();
  }
});

test("installed plugin guidance and tools refresh in an existing session without credential reconfiguration", async () => {
  const mock = await startMock([() => textReply("first"), () => textReply("second"), () => textReply("third")]);
  const p = launch(mkdtempSync(join(tmpdir(), "asky-plugin-refresh-")));
  try {
    await handshake(p, mock);
    p.send({ type: "prompt", request: request("plugin-before", "hello") });
    await p.next(f => f.type === "taskState" && f.taskID === "plugin-before" && f.state === "completed");
    const pluginTool = { ...TOOLS[0], name: "plugin_orca__submit_task", source: "plugins", confirmation: "explicitDirectOtherwiseConfirm", externallyExposable: false };
    p.send({ type: "resources", tools: [pluginTool], pluginGuidance: ["ORCA_PLUGIN_GUIDANCE_MARKER"] });
    p.send({ type: "prompt", request: request("plugin-enabled", "hello again") });
    await p.next(f => f.type === "taskState" && f.taskID === "plugin-enabled" && f.state === "completed");
    assert.ok(mock.requests[1].body.tools.some((t: any) => t.function.name === pluginTool.name));
    assert.ok(mock.requests[1].body.messages.some((m: any) => m.role === "system" && m.content.includes("ORCA_PLUGIN_GUIDANCE_MARKER")));
    p.send({ type: "resources", tools: [], pluginGuidance: [] });
    p.send({ type: "prompt", request: request("plugin-disabled", "one more") });
    await p.next(f => f.type === "taskState" && f.taskID === "plugin-disabled" && f.state === "completed");
    assert.ok(!mock.requests[2].body.tools?.some((t: any) => t.function.name === pluginTool.name));
    assert.ok(!mock.requests[2].body.messages.some((m: any) => m.role === "system" && m.content.includes("ORCA_PLUGIN_GUIDANCE_MARKER")));
    assert.ok(mock.requests[2].body.messages.some((m: any) => JSON.stringify(m).includes("hello again")));
  } finally { p.child.stdin.end(); assert.equal(await p.exit, 0); mock.server.close(); }
});

test("runtime rejects a v1 host handshake", async () => {
  const p = launch(mkdtempSync(join(tmpdir(), "asky-protocol-mismatch-")));
  try { p.send({ type: "hello", protocol: 1 }); assert.match((await p.next(f => f.type === "error")).message, /protocol mismatch/); }
  finally { p.child.stdin.end(); assert.equal(await p.exit, 0); }
});

test("public web search round trip preserves sources and search policy", async () => {
  const mock = await startMock([() => toolCallReply("web_search", { query: "Swift", count: 3 }), () => textReply("来源：[Swift](https://swift.org/)")]);
  const p = launch(mkdtempSync(join(tmpdir(), "asky-web-")));
  try {
    await handshake(p, mock);
    const web = { name: "web_search", summary: "Search public web", inputSchema: { type: "object", properties: { query: { type: "string" }, count: { type: "integer" } }, required: ["query"] }, source: "web", effect: "read", confirmation: "never", externallyExposable: false, agentExposable: true };
    p.send({ type: "resources", tools: [web], pluginGuidance: [] });
    p.send({ type: "prompt", request: request("web1", "联网搜索 Swift") });
    const call = await p.next((f) => f.type === "toolCall");
    assert.equal(call.tool, "web_search");
    assert.deepEqual(call.arguments, { query: "Swift", count: 3 });
    p.send({ type: "toolResult", callID: call.callID, result: { requestID: call.callID, status: "completed", output: { results: [{ title: "Swift", url: "https://swift.org/", snippet: "Swift language" }], contentType: "search_snippets" } } });
    const reply = await p.next((f) => f.type === "message");
    assert.ok(reply.text.includes("https://swift.org/"));
    await p.next((f) => f.type === "taskState" && f.state === "completed");
    assert.ok(JSON.stringify(mock.requests[1].body.messages).includes("search_snippets"));
    assert.ok(mock.requests[0].body.messages.find((m: any) => m.role === "system").content.includes("搜索摘要不等于已读取网页全文"));
    p.send({ type: "shutdown" });
    assert.equal(await p.exit, 0);
  } finally { p.child.kill(); await new Promise<void>((r) => mock.server.close(() => r())); }
});


test("Messages search reaches native host and result returns to model", async () => {
  const mock = await startMock([() => toolCallReply("messages_search", { query: "观鹤" }), () => textReply("短信报名地点是杭州西溪")]);
  const p = launch(mkdtempSync(join(tmpdir(), "asky-messages-")));
  try {
    await handshake(p, mock, [...TOOLS, {
      name: "messages_search", summary: "查询最近30天短信", inputSchema: { type: "object", properties: { query: { type: "string" } }, required: ["query"], additionalProperties: false },
      source: "messages", effect: "read", confirmation: "never", externallyExposable: false, agentExposable: true,
    }]);
    p.send({ type: "prompt", request: request("sms", "帮我查短信里的观鹤报名地点") });
    const call = await p.next((f) => f.type === "toolCall");
    assert.equal(call.tool, "messages_search");
    assert.deepEqual(call.arguments, { query: "观鹤" });
    p.send({ type: "toolResult", callID: call.callID, result: { requestID: call.callID, status: "completed", output: { messages: [{ id: "1", sender: "尾号5678", date: "2026-10-12T10:00:00+08:00", text: "观鹤报名地点：杭州西溪" }], hasMore: false, scanLimitReached: false } } });
    await p.next((f) => f.type === "taskState" && f.state === "completed");
    assert.ok(JSON.stringify(mock.requests[1].body.messages).includes("杭州西溪"));
    const system = mock.requests[0].body.messages.find((m: any) => m.role === "system").content;
    assert.ok(system.includes("用户要求查短信时调用 messages_search"));
    p.send({ type: "shutdown" });
    assert.equal(await p.exit, 0);
  } finally { p.child.kill("SIGKILL"); mock.server.close(); }
});

test("automatic compaction reports loading and resumes the running task", async () => {
  const mock = await startMock([
    () => textReply("好的"),
    () => sse([
      { ...base, choices: [{ index: 0, delta: { role: "assistant", content: "已记录" } }] },
      { ...base, choices: [{ index: 0, delta: {}, finish_reason: "stop" }], usage: { prompt_tokens: 120000, completion_tokens: 3, total_tokens: 120003 } },
    ]),
    () => textReply("对话摘要：用户提供了一段较长的资料"),
  ]);
  const p = launch(mkdtempSync(join(tmpdir(), "kula-compact-")));
  try {
    await handshake(p, mock);
    p.send({ type: "prompt", request: request("warmup", "我们开始吧") });
    await p.next((f) => f.type === "taskState" && f.taskID === "warmup" && f.state === "completed");
    p.send({ type: "prompt", request: request("compact", "资料内容。".repeat(20000)) });
    await p.next((f) => f.type === "taskState" && f.state === "compacting");
    await p.next((f) => f.type === "taskState" && f.taskID === "compact" && f.state === "completed");
    const states = p.frames.filter((f) => f.type === "taskState" && f.taskID === "compact").map((f) => f.state);
    const start = states.indexOf("compacting");
    assert.equal(states[start + 1], "running");
    assert.equal(states.at(-1), "completed");
    assert.ok(mock.requests.length >= 3, "the SDK must actually request a compaction summary");
  } finally {
    p.send({ type: "shutdown" });
    await p.exit;
    mock.server.close();
  }
});

test("MapKit tools reach the model, route results return, and disabling removes tools", async () => {
  const endpoint = { name: "Station", latitude: 31.2, longitude: 121.3 };
  const args = { origin: endpoint, destination: { ...endpoint, name: "Temple", longitude: 121.4 }, modes: ["transit"] };
  const mock = await startMock([() => toolCallReply("maps_routes", args), () => textReply("公交预计 30 分钟"), () => textReply("请开启 MapKit")]);
  const p = launch(mkdtempSync(join(tmpdir(), "asky-maps-")));
  const schema = { type: "object", properties: { origin: { type: "object" }, destination: { type: "object" }, modes: { type: "array", items: { type: "string" } } }, required: ["origin", "destination"] };
  const maps = ["maps_search_places", "maps_routes"].map(name => ({ name, summary: "Apple MapKit", inputSchema: schema, source: "maps", effect: "read", confirmation: "never", externallyExposable: false, agentExposable: true }));
  try {
    await handshake(p, mock, maps);
    p.send({ type: "prompt", request: request("maps-on", "安排今天三个日程的出行") });
    const call = await p.next(f => f.type === "toolCall");
    assert.equal(call.tool, "maps_routes");
    assert.deepEqual(call.arguments, args);
    p.send({ type: "toolResult", callID: call.callID, result: { requestID: call.callID, status: "completed", output: { provider: "Apple MapKit", routes: [{ mode: "transit", durationSeconds: 1800 }], unavailableModes: [] } } });
    await p.next(f => f.type === "taskState" && f.taskID === "maps-on" && f.state === "completed");
    const names = mock.requests[0].body.tools.map((t: any) => t.function.name);
    assert.ok(names.includes("maps_routes") && names.includes("maps_search_places"));
    assert.ok(!names.includes("web_search"));
    const prompt = mock.requests[0].body.messages.find((m: any) => m.role === "system").content;
    assert.ok(prompt.includes("不用 web_search 代替路线查询"));
    assert.ok(prompt.includes("打车不产生自有车辆遗留约束"));
    assert.ok(JSON.stringify(mock.requests[1].body.messages).includes("durationSeconds"));
    p.send({ type: "resources", tools: [], pluginGuidance: [] });
    p.send({ type: "prompt", request: request("maps-off", "再规划一次") });
    await p.next(f => f.type === "taskState" && f.taskID === "maps-off" && f.state === "completed");
    assert.ok(!(mock.requests[2].body.tools ?? []).some((t: any) => t.function.name.startsWith("maps_")));
  } finally { p.child.stdin.end(); assert.equal(await p.exit, 0); mock.server.close(); }
});
