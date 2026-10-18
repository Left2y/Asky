import Foundation
import Contracts

public struct PluginRuntimeConfiguration: Sendable {
    public var nodePath: String?
    public var runnerPath: String?
    public init(nodePath: String? = nil, runnerPath: String? = nil) {
        self.nodePath = nodePath; self.runnerPath = runnerPath
    }
}
public struct PluginConfigurationField: Codable, Sendable, Hashable, Identifiable {
    public var key: String
    public var label: String
    public var type: String
    public var required: Bool?
    public var defaultValue: JSONValue?
    public var options: [String]?
    public var id: String { key }
}
public struct PluginTool: Codable, Sendable, Hashable {
    public var name: String
    public var description: String
    public var inputSchema: JSONValue
    public var effect: ToolEffect
    public var confirmation: ConfirmationRule
    public var timeoutSeconds: Int?
}
public struct PluginManifest: Codable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var version: String
    public var apiVersion: Int
    public var entry: String
    public var instructions: String?
    /// Optional artwork relative to the plugin directory. Unreadable artwork uses the host fallback.
    public var icon: String?
    public var configuration: [PluginConfigurationField]?
    public var tools: [PluginTool]

    public func validate(at root: URL) throws {
        let valid: (String) -> Bool = { $0.range(of: "^[a-z][a-z0-9_-]{0,63}$", options: .regularExpression) != nil }
        guard apiVersion == 1, valid(id), !name.isEmpty, !version.isEmpty, !tools.isEmpty,
              Set(tools.map(\.name)).count == tools.count,
              Set((configuration ?? []).map(\.key)).count == (configuration ?? []).count else {
            throw ToolError(.invalidArguments, CoreLocalization.text("插件清单无效或 API 版本不兼容"))
        }
        _ = try Self.resource(entry, at: root)
        if let instructions { _ = try Self.resource(instructions, at: root) }
        for field in configuration ?? [] {
            guard valid(field.key), ["text", "path", "boolean", "enum"].contains(field.type),
                  field.type != "enum" || !(field.options ?? []).isEmpty else { throw ToolError(.invalidArguments, CoreLocalization.text("插件配置字段无效")) }
        }
        for tool in tools {
            guard valid(tool.name), tool.inputSchema["type"]?.stringValue == "object",
                  (1...240).contains(tool.timeoutSeconds ?? 20),
                  tool.effect != .write || tool.confirmation != .never else {
                throw ToolError(.invalidArguments, CoreLocalization.format("插件工具定义无效：%@", String(describing: tool.name)))
            }
        }
    }
    public static func resource(_ path: String, at root: URL) throws -> URL {
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        let file = root.appending(path: path).resolvingSymlinksInPath().standardizedFileURL
        guard !path.hasPrefix("/"), file.path.hasPrefix(base.path + "/"),
              FileManager.default.fileExists(atPath: file.path),
              (try file.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else {
            throw ToolError(.invalidArguments, CoreLocalization.format("插件文件不存在或路径无效：%@", String(describing: path)))
        }
        return file
    }
}
public struct InstalledPlugin: Codable, Sendable, Hashable, Identifiable {
    public var id: String { manifest.id }
    public var manifest: PluginManifest
    public var repository: String
    public var commit: String
    public var enabled: Bool
    public var configuration: [String: JSONValue]
    public var previousCommit: String?
    public var isOfficial: Bool { PluginManager.officialRepositories.contains(repository) }
    public var needsConfiguration: Bool {
        (manifest.configuration ?? []).contains { field in
            field.required == true && (configuration[field.key] == nil || configuration[field.key]?.stringValue == "")
        }
    }
}
