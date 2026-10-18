import Foundation
import Contracts

/// Minimal MCP server over stdio (JSON-RPC 2.0, newline-delimited): initialize, ping, tools/list, tools/call.
/// Kept dependency-free so the bridge holds no third-party code; it only forwards to the app.
public struct MCPStdioServer: Sendable {
    public static let supportedProtocolVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]

    public let name: String
    public let version: String
    private let listTools: @Sendable () throws -> [ToolDefinition]
    private let callTool: @Sendable (String, JSONValue) throws -> ExecutionResult

    public init(name: String = "asky", version: String,
                listTools: @escaping @Sendable () throws -> [ToolDefinition],
                callTool: @escaping @Sendable (String, JSONValue) throws -> ExecutionResult) {
        self.name = name
        self.version = version
        self.listTools = listTools
        self.callTool = callTool
    }

    /// Handles one inbound line; returns the encoded response line, or nil for notifications.
    public func handle(_ line: Data) -> Data? {
        guard let msg = try? JSONDecoder().decode(JSONValue.self, from: line), let obj = msg.objectValue else {
            return Self.encode(["jsonrpc": "2.0", "id": nil, "error": ["code": -32700, "message": .string(CoreLocalization.text("请求解析失败"))]])
        }
        guard let method = obj["method"]?.stringValue else {
            // A response from the client (we never send requests) or garbage: ignore.
            return nil
        }
        guard let id = obj["id"], id != .null else { return nil }  // notification
        let params = obj["params"] ?? [:]
        do {
            return Self.encode(["jsonrpc": "2.0", "id": id, "result": try respond(method, params)])
        } catch let e as RPCError {
            return Self.encode(["jsonrpc": "2.0", "id": id, "error": ["code": .number(Double(e.code)), "message": .string(e.message)]])
        } catch {
            return Self.encode(["jsonrpc": "2.0", "id": id, "error": ["code": -32603, "message": .string(String(describing: error))]])
        }
    }

    struct RPCError: Error { let code: Int; let message: String }

    private func respond(_ method: String, _ params: JSONValue) throws -> JSONValue {
        switch method {
        case "initialize":
            let asked = params["protocolVersion"]?.stringValue ?? ""
            let v = Self.supportedProtocolVersions.contains(asked) ? asked : Self.supportedProtocolVersions[0]
            return ["protocolVersion": .string(v),
                    "capabilities": ["tools": ["listChanged": false]],
                    "serverInfo": ["name": .string(name), "version": .string(version)]]
        case "ping":
            return [:]
        case "tools/list":
            let tools = try listTools().map { d -> JSONValue in
                var schema = d.inputSchema
                if schema.objectValue == nil || schema["type"] == nil { schema = ["type": "object", "properties": [:]] }
                return ["name": .string(d.name), "description": .string(d.summary), "inputSchema": schema]
            }
            return ["tools": .array(tools)]
        case "tools/call":
            guard let tool = params["name"]?.stringValue else { throw RPCError(code: -32602, message: CoreLocalization.text("缺少工具名称")) }
            do {
                return Self.render(try callTool(tool, params["arguments"] ?? [:]))
            } catch {
                return ["content": [["type": "text", "text": .string(String(describing: error))]], "isError": true]
            }
        default:
            throw RPCError(code: -32601, message: CoreLocalization.format("未知方法：%@", method))
        }
    }

    static func render(_ r: ExecutionResult) -> JSONValue {
        var lines = ["status: \(r.status.rawValue)"]
        switch r.status {
        case .completed: lines.append(CoreLocalization.text("已在 Asky 中完成。"))
        case .rejected: lines.append(CoreLocalization.text("未执行。"))
        case .pendingVerification: lines.append(CoreLocalization.text("结果未能核实，请勿假定已完成。"))
        case .suggestion: lines.append(CoreLocalization.text("仅为建议，未执行。"))
        default: break
        }
        if let e = r.error { lines.append("error: \(e.code.rawValue) \(e.message)") }
        if let o = r.readback ?? r.output { lines.append(String(decoding: o.canonicalData(), as: UTF8.self)) }
        return ["content": [["type": "text", "text": .string(lines.joined(separator: "\n"))]],
                "isError": .bool(r.status != .completed && r.status != .suggestion)]
    }

    static func encode(_ v: JSONValue) -> Data {
        var d = v.canonicalData()
        d.append(0x0A)
        return d
    }
}
