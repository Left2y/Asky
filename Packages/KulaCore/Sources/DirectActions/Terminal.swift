import Foundation
import Synchronization

public enum TerminalEvent: Sendable, Equatable {
    case stdout(String)
    case stderr(String)
    case exited(code: Int32, spilledOutput: URL?)
    case handedOffToTerminal
}

/// Runs an explicit, user-submitted command (never from AI without per-command authorization).
/// Output beyond `memoryLimit` bytes is streamed to a file; only a tail is kept in memory.
public final class TerminalRunner: Sendable {
    public static let interactiveCommands: Set<String> = [
        "vim", "vi", "nvim", "nano", "emacs", "top", "htop", "less", "more", "man", "ssh", "sftp", "ftp",
        "python", "python3", "node", "irb", "sqlite3", "mysql", "psql", "watch", "tmux", "screen", "claude",
    ]

    static let replCommands: Set<String> = ["python", "python3", "node", "irb", "sqlite3", "mysql", "psql"]

    public static func isInteractive(_ command: String) -> Bool {
        let parts = command.trimmingCharacters(in: .whitespaces).split(separator: " ")
        let exe = ((parts.first.map(String.init) ?? "") as NSString).lastPathComponent
        guard interactiveCommands.contains(exe) else { return false }
        // REPLs are only interactive without arguments (`python3 script.py` is fine).
        if replCommands.contains(exe) { return parts.count == 1 }
        return true
    }

    private let process = Mutex<Process?>(nil)
    public let memoryLimit: Int
    public let spillDirectory: URL

    public init(memoryLimit: Int = 64 * 1024, spillDirectory: URL) {
        self.memoryLimit = memoryLimit
        self.spillDirectory = spillDirectory
    }

    public func run(_ command: String, workingDirectory: URL,
                    environment: [String: String]? = nil) -> AsyncStream<TerminalEvent> {
        AsyncStream { continuation in
            if Self.isInteractive(command) {
                continuation.yield(.handedOffToTerminal)
                continuation.finish()
                return
            }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = ["-c", command]
            p.currentDirectoryURL = workingDirectory
            if let environment { p.environment = environment }
            p.standardInput = FileHandle.nullDevice
            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err

            let spill = Spill(limit: memoryLimit, directory: spillDirectory)
            let group = DispatchGroup()
            for (pipe, isErr) in [(out, false), (err, true)] {
                group.enter()
                pipe.fileHandleForReading.readabilityHandler = { h in
                    let data = h.availableData
                    if data.isEmpty {
                        h.readabilityHandler = nil
                        group.leave()
                        return
                    }
                    if spill.append(data) {
                        let s = String(decoding: data, as: UTF8.self)
                        continuation.yield(isErr ? .stderr(s) : .stdout(s))
                    }
                }
            }
            p.terminationHandler = { proc in
                group.notify(queue: .global()) {
                    continuation.yield(.exited(code: proc.terminationStatus, spilledOutput: spill.finish()))
                    continuation.finish()
                }
            }
            continuation.onTermination = { [weak self] reason in
                if case .cancelled = reason { self?.stop() }
            }
            do {
                try p.run()
                process.withLock { $0 = p }
            } catch {
                continuation.yield(.stderr("无法启动命令：\(error.localizedDescription)\n"))
                continuation.yield(.exited(code: -1, spilledOutput: nil))
                continuation.finish()
            }
        }
    }

    /// Terminates the running command (SIGTERM, then SIGKILL after 2 s).
    public func stop() {
        guard let p = process.withLock({ $0 }), p.isRunning else { return }
        p.terminate()
        let pid = p.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if p.isRunning { kill(pid, SIGKILL) }
        }
    }

    /// Keeps up to `limit` bytes for live display; once exceeded, everything goes to a file.
    final class Spill: @unchecked Sendable {
        let limit: Int
        let directory: URL
        private let lock = NSLock()
        private var buffered = Data()
        private var file: FileHandle?
        private var url: URL?

        init(limit: Int, directory: URL) {
            self.limit = limit
            self.directory = directory
        }

        /// Returns true if the chunk should still be shown live.
        func append(_ data: Data) -> Bool {
            lock.lock(); defer { lock.unlock() }
            if file == nil, buffered.count + data.count <= limit {
                buffered.append(data)
                return true
            }
            if file == nil {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let u = directory.appendingPathComponent("terminal-\(UUID().uuidString).log")
                FileManager.default.createFile(atPath: u.path, contents: buffered)
                file = try? FileHandle(forWritingTo: u)
                file?.seekToEndOfFile()
                url = u
                buffered = Data()
            }
            file?.write(data)
            return false
        }

        func finish() -> URL? {
            lock.lock(); defer { lock.unlock() }
            try? file?.close()
            return url
        }
    }
}
