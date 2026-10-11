import assert from "node:assert/strict";
import test from "node:test";
import { describeResult } from "../src/bridge.js";

test("read results do not claim write readback verification", () => {
  const read = describeResult({ requestID: "read", status: "completed", output: [] });
  assert.ok(!read.includes("回读确认"));
  assert.ok(read.includes('"output":[]'));
  const write = describeResult({ requestID: "write", status: "completed", readback: { id: "event" } });
  assert.ok(write.includes("回读确认"));
});
