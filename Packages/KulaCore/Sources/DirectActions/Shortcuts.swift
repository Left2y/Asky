import Foundation
import Contracts

public enum ShortcutRunState: Sendable, Equatable {
    case started
    case completed(output: String)
    case failed(message: String)
}

/// macOS Shortcuts via the system `shortcuts` command-line interface.
public enum ShortcutsService {
    static let tool = URL(fileURLWithPath: "/usr/bin/shortcuts")

    public static func list() async -> [String] {
        guard let r = try? await runTool(["list"]), r.status == 0 else { return [] }
        return r.stdout.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
    }

    public static func run(name: String, input: String? = nil) -> AsyncStream<ShortcutRunState> {
        AsyncStream { c in
            c.yield(.started)
            let task = Task {
                var inputFile: URL?
                var args = ["run", name]
                if let input {
                    let u = FileManager.default.temporaryDirectory.appendingPathComponent("kula-sc-\(UUID().uuidString).txt")
                    try? input.write(to: u, atomically: true, encoding: .utf8)
                    inputFile = u
                    args += ["--input-path", u.path]
                }
                let outFile = FileManager.default.temporaryDirectory.appendingPathComponent("kula-sc-out-\(UUID().uuidString)")
                args += ["--output-path", outFile.path]
                defer {
                    if let inputFile { try? FileManager.default.removeItem(at: inputFile) }
                    try? FileManager.default.removeItem(at: outFile)
                }
                do {
                    let r = try await runTool(args)
                    if r.status == 0 {
                        let out = (try? String(contentsOf: outFile, encoding: .utf8)) ?? r.stdout
                        c.yield(.completed(output: String(out.prefix(16 * 1024))))
                    } else {
                        c.yield(.failed(message: r.stderr.isEmpty ? CoreLocalization.format("退出码 %@", String(describing: r.status)) : r.stderr))
                    }
                } catch {
                    c.yield(.failed(message: error.localizedDescription))
                }
                c.finish()
            }
            c.onTermination = { _ in task.cancel() }
        }
    }

    struct ToolResult { var status: Int32; var stdout: String; var stderr: String }

    static func runTool(_ args: [String]) async throws -> ToolResult {
        try await withCheckedThrowingContinuation { cont in
            let p = Process()
            p.executableURL = tool
            p.arguments = args
            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err
            p.terminationHandler = { proc in
                let o = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                let e = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                cont.resume(returning: ToolResult(status: proc.terminationStatus, stdout: o, stderr: e))
            }
            do { try p.run() } catch { cont.resume(throwing: error) }
        }
    }
}
