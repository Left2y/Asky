// Entry point. Must run before Pi is imported so that nothing Pi prints can reach the protocol channel.
import { mkdirSync } from "node:fs";
import { join, resolve } from "node:path";

const protocolWrite = process.stdout.write.bind(process.stdout);
// Host closed our output: there is nobody left to serve.
process.stdout.on("error", () => process.exit(0));
// Everything except protocol frames goes to stderr (console.log included).
process.stdout.write = process.stderr.write.bind(process.stderr) as typeof process.stdout.write;

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const dataDir = resolve(arg("--data-dir") ?? join(process.env.TMPDIR ?? "/tmp", "kulahere-runtime"));
const agentDir = join(dataDir, "pi");
mkdirSync(join(agentDir, "sessions"), { recursive: true, mode: 0o700 });

// No automatic network activity besides the configured model endpoint; no ~/.pi discovery.
Object.assign(process.env, {
  PI_OFFLINE: "1",
  PI_SKIP_VERSION_CHECK: "1",
  PI_TELEMETRY: "0",
  PI_CODING_AGENT_DIR: agentDir,
  PI_CODING_AGENT_SESSION_DIR: join(agentDir, "sessions"),
});
// Credentials only ever arrive through `configure` on stdin.
for (const k of Object.keys(process.env)) if (/(_API_KEY|_TOKEN|_SECRET)$/i.test(k)) delete process.env[k];

const { Runtime } = await import("./runtime.js");
new Runtime((line) => protocolWrite(line), dataDir, agentDir).start();
