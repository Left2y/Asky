import Foundation

/// Locates Node and the built AgentRuntime entry, and spawns it with a credential-free environment.
public struct NodeRuntimeLauncher: Sendable {
    public var nodePath: String
    public var entryScript: String
    public var dataDirectory: String
    public var stderrLog: String?

    public init(nodePath: String, entryScript: String, dataDirectory: String, stderrLog: String? = nil) {
        self.nodePath = nodePath
        self.entryScript = entryScript
        self.dataDirectory = dataDirectory
        self.stderrLog = stderrLog
    }

    /// Bundled node first (`Resources/node/bin/node`), then common install locations.
    public static func findNode(bundleResources: URL? = nil,
                                candidates: [String] = ["/opt/homebrew/bin/node", "/usr/local/bin/node"]) -> String? {
        var paths: [String] = []
        if let r = bundleResources { paths.append(r.appending(path: "node/bin/node").path) }
        paths += candidates
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Only PATH/HOME/TMPDIR/locale are passed; never keys or tokens.
    public func environment() -> [String: String] {
        let src = ProcessInfo.processInfo.environment
        var env: [String: String] = [
            "PATH": "/usr/bin:/bin",
            "HOME": dataDirectory,
            "TMPDIR": NSTemporaryDirectory(),
        ]
        for k in ["LANG", "LC_ALL", "TZ"] { if let v = src[k] { env[k] = v } }
        return env
    }

    public func spawn() throws -> any RuntimeProcess {
        try FileManager.default.createDirectory(atPath: dataDirectory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        return try SpawnedRuntimeProcess(executable: nodePath, arguments: [entryScript, "--data-dir", dataDirectory],
                                         workingDirectory: dataDirectory, environment: environment(),
                                         stderrLog: stderrLog)
    }

    public var launcher: AgentHost.Launcher {
        let me = self
        return { try me.spawn() }
    }
}
