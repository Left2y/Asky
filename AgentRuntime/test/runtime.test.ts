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
  { name: "memory_search", summary: "检索记忆", inputSchema: { type: "object", properties: { query: { type: "string" } }, required: ["query"], additionalProperties: false },
    source: "memory", effect: "read", confirmation: "never", externallyExposable: false, agentExposable: true },
  { name: "hidden_tool", summary: "不应暴露", inputSchema: { type: "object", properties: {}, additionalProperties: false },
    source: "terminal", effect: "read", confirmation: "never", externallyExposable: false, agentExposable: false },
];

async function handshake(p: Proc, mock: Mock) {
  p.send({ type: "hello", protocol: 1 });
  const ready = await p.next((f) => f.type === "ready");
  assert.equal(ready.protocol, 1);
  assert.match(ready.runtime, /pi\/1\.1\.0/);
  p.send({ type: "configure", baseURL: mock.url, model: "mock-model", apiKey: KEY, tools: TOOLS, maxToolRounds: 8 });
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
    assert.deepEqual(names, ["ask_user", "calendar_create", "memory_search"]);
    // Credential: injected key used; environment key ignored.
    assert.ok(mock.requests.every((r) => r.auth === `Bearer ${KEY}`));
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
  const mock = await startMock([() => toolCallReply("memory_search", { query: "x" }), () => textReply("不应到达")]);
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
