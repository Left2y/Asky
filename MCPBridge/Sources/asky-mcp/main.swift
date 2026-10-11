// asky-mcp: stdio MCP server that forwards to the running Asky app over the local link.
// It never reads system data itself and holds no system permissions; the app decides everything.
import Foundation
import Contracts
import MCPLink

/// Lazily (re)connects so the bridge survives the app starting later or restarting.
final class Link: @unchecked Sendable {
    private let lock = NSLock()
    private let socketPath: String
    private let credential: String
    private var client: MCPLinkClient?

    init(socketPath: String, credential: String) {
        self.socketPath = socketPath
        self.credential = credential
    }

    func with<T>(_ body: (MCPLinkClient) throws -> T) throws -> T {
        try lock.withLock {
            for attempt in 0..<2 {
                do {
                    let c = try client ?? MCPLinkClient(socketPath: socketPath, credential: credential)
                    client = c
                    return try body(c)
                } catch MCPLinkError.closed where attempt == 0 {
                    client = nil
                } catch {
                    client = nil
                    throw error
                }
            }
            throw MCPLinkError.closed
        }
    }
}

let env = ProcessInfo.processInfo.environment
guard let credential = (env["ASKY_MCP_CREDENTIAL"] ?? env["KULAHERE_MCP_CREDENTIAL"]), !credential.isEmpty else {
    FileHandle.standardError.write(Data("asky-mcp: ASKY_MCP_CREDENTIAL is not set. Create an instance in Asky › 设置 › 外部 MCP.\n".utf8))
    exit(64)
}
signal(SIGPIPE, SIG_IGN)
let link = Link(socketPath: env["ASKY_MCP_SOCKET"] ?? env["KULAHERE_MCP_SOCKET"] ?? MCPLink.defaultSocketPath(), credential: credential)
let server = MCPStdioServer(version: "0.1.0",
                            listTools: { try link.with { try $0.listTools() } },
                            callTool: { tool, args in try link.with { try $0.call(tool: tool, arguments: args) } })

var framer = LineFramer()
var buf = [UInt8](repeating: 0, count: 64 * 1024)
while true {
    let n = read(STDIN_FILENO, &buf, buf.count)
    if n < 0, errno == EINTR { continue }
    guard n > 0 else { break }
    for line in framer.push(Data(buf[0..<n])) {
        if let out = server.handle(line), !writeAll(STDOUT_FILENO, out) { exit(0) }
    }
}
