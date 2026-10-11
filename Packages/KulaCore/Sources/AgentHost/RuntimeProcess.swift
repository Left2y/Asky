import Foundation
import Darwin
import Synchronization

/// A managed runtime child process speaking the JSONL protocol.
public protocol RuntimeProcess: Sendable {
    var pid: Int32 { get }
    /// Raw stdout chunks; finishes when the process exits.
    var output: AsyncStream<Data> { get }
    func write(_ data: Data) throws
    /// Closes stdin so a well-behaved runtime exits on its own.
    func closeInput()
    /// Kills the whole process group (runtime + any descendants).
    func terminate(force: Bool)
    /// Waits for exit and returns the status.
    func waitForExit() async -> Int32
}

/// Spawns the runtime in its own process group so termination reaches every descendant.
/// Environment is minimal and never contains credentials.
public final class SpawnedRuntimeProcess: RuntimeProcess {
    public let pid: Int32
    public let output: AsyncStream<Data>
    private let stdinFD: Int32
    /// Must be retained: dropping it closes the read end and the child gets EPIPE.
    private let stdoutHandle: FileHandle
    private final class ExitBox: Sendable {
        let state = Mutex<(code: Int32?, waiters: [CheckedContinuation<Int32, Never>])>((nil, []))
    }
    private let exitBox = ExitBox()
    private let inputClosed = Mutex(false)

    public init(executable: String, arguments: [String], workingDirectory: String,
                environment: [String: String], stderrLog: String?) throws {
        var inPipe: [Int32] = [0, 0], outPipe: [Int32] = [0, 0]
        guard pipe(&inPipe) == 0, pipe(&outPipe) == 0 else { throw POSIXError(.EMFILE) }

        var fa: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fa)
        defer { posix_spawn_file_actions_destroy(&fa) }
        posix_spawn_file_actions_adddup2(&fa, inPipe[0], 0)
        posix_spawn_file_actions_adddup2(&fa, outPipe[1], 1)
        if let stderrLog {
            posix_spawn_file_actions_addopen(&fa, 2, stderrLog, O_WRONLY | O_CREAT | O_APPEND, 0o600)
        } else {
            posix_spawn_file_actions_addopen(&fa, 2, "/dev/null", O_WRONLY, 0)
        }
        for fd in [inPipe[0], inPipe[1], outPipe[0], outPipe[1]] { posix_spawn_file_actions_addclose(&fa, fd) }
        if #available(macOS 26, *) {
            posix_spawn_file_actions_addchdir(&fa, workingDirectory)
        } else {
            posix_spawn_file_actions_addchdir_np(&fa, workingDirectory)
        }

        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))
        posix_spawnattr_setpgroup(&attr, 0)

        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }

        var child: pid_t = 0
        let rc = posix_spawn(&child, executable, &fa, &attr, argv, envp)
        close(inPipe[0]); close(outPipe[1])
        guard rc == 0 else {
            close(inPipe[1]); close(outPipe[0])
            throw POSIXError(POSIXErrorCode(rawValue: rc) ?? .ENOENT)
        }
        pid = child
        stdinFD = inPipe[1]
        _ = fcntl(stdinFD, F_SETNOSIGPIPE, 1)

        let handle = FileHandle(fileDescriptor: outPipe[0], closeOnDealloc: true)
        stdoutHandle = handle
        output = AsyncStream(bufferingPolicy: .bufferingOldest(256)) { cont in
            handle.readabilityHandler = { h in
                let d = h.availableData
                if d.isEmpty {
                    h.readabilityHandler = nil
                    cont.finish()
                } else {
                    cont.yield(d)
                }
            }
        }

        let source = DispatchSource.makeProcessSource(identifier: child, eventMask: .exit, queue: .global(qos: .utility))
        let box = exitBox
        source.setEventHandler {
            var status: Int32 = 0
            waitpid(child, &status, 0)
            let code: Int32 = (status & 0x7f) == 0 ? (status >> 8) & 0xff : -(status & 0x7f)
            let waiters = box.state.withLock { s -> [CheckedContinuation<Int32, Never>] in
                s.code = code
                defer { s.waiters = [] }
                return s.waiters
            }
            waiters.forEach { $0.resume(returning: code) }
            source.cancel()
        }
        source.activate()
    }

    public func write(_ data: Data) throws {
        try data.withUnsafeBytes { buf in
            var off = 0
            while off < buf.count {
                let n = Darwin.write(stdinFD, buf.baseAddress! + off, buf.count - off)
                if n < 0 {
                    if errno == EINTR { continue }
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EPIPE)
                }
                off += n
            }
        }
    }

    public func closeInput() {
        let already = inputClosed.withLock { c -> Bool in defer { c = true }; return c }
        if !already { close(stdinFD) }
    }

    public func terminate(force: Bool) {
        kill(-pid, force ? SIGKILL : SIGTERM)
    }

    public func waitForExit() async -> Int32 {
        await withCheckedContinuation { cont in
            let code = exitBox.state.withLock { s -> Int32? in
                if let c = s.code { return c }
                s.waiters.append(cont)
                return nil
            }
            if let code { cont.resume(returning: code) }
        }
    }

    deinit { closeInput() }
}
