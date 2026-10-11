import type { ExecutionResult, FrameWriter, JSONValue } from "./protocol.js";

/** Forwards tool calls to the native ToolService and awaits `toolResult`. The runtime never executes tools itself. */
export class NativeBridge {
  private pending = new Map<string, { taskID: string; resolve: (r: ExecutionResult) => void }>();
  private seq = 0;

  constructor(private readonly send: FrameWriter) {}

  call(taskID: string, tool: string, args: JSONValue, explicit: boolean, signal?: AbortSignal): Promise<ExecutionResult> {
    const callID = `${taskID}:${++this.seq}`;
    return new Promise((resolve) => {
      const done = (r: ExecutionResult) => {
        if (!this.pending.delete(callID)) return;
        signal?.removeEventListener("abort", onAbort);
        resolve(r);
      };
      // An aborted call is reported as unknown to the model; the native side owns the real outcome.
      const onAbort = () => done({ requestID: callID, status: "cancelled", error: { code: "cancelled", message: "已取消" } });
      if (signal?.aborted) return onAbort();
      signal?.addEventListener("abort", onAbort, { once: true });
      this.pending.set(callID, { taskID, resolve: done });
      this.send({ type: "toolCall", taskID, callID, tool, arguments: args, intent: explicit ? "explicitRequest" : "aiSuggested" });
    });
  }

  resolve(callID: string, result: ExecutionResult): void {
    this.pending.get(callID)?.resolve(result);
  }

  cancelTask(taskID: string): void {
    for (const [id, p] of this.pending) {
      if (p.taskID === taskID) p.resolve({ requestID: id, status: "cancelled", error: { code: "cancelled", message: "已取消" } });
    }
  }

  get inFlight(): number {
    return this.pending.size;
  }
}

/** Model-facing summary of a native result. Status is spelled out so the model cannot claim success it did not get. */
export function describeResult(r: ExecutionResult): string {
  const body: Record<string, JSONValue> = { status: r.status };
  if (r.output !== undefined) body.output = r.output;
  if (r.readback !== undefined) body.readback = r.readback;
  if (r.error) body.error = r.error;
  if (r.targets?.length) body.targets = r.targets;
  const note: Record<string, string> = {
    completed: r.readback !== undefined ? "已执行并经原生回读确认。" : "原生读取/执行成功；以下为本次工具返回的数据。",
    suggestion: "未执行：这是 AI 推断的操作，已作为建议展示给用户，由用户决定。",
    rejected: "未执行：用户拒绝了该操作。",
    cancelled: "未执行：操作已取消。",
    failed: "未执行：执行失败。",
    pendingVerification: "结果未知：请告知用户需要自行核实，不要重试写入。",
    awaitingConfirmation: "未执行：等待用户确认。",
  };
  return `${note[r.status] ?? ""}\n${JSON.stringify(body)}`;
}
