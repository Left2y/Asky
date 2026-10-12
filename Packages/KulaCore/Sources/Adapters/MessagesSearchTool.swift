import Foundation
import Contracts
import ToolService

/// Explicit, bounded conversation reads. Full Disk Access alone never enables AI access.
public struct MessagesSearchTool: ToolAdapter {
    private let reader: MessagesHistoryReader
    private let enabled: @Sendable () -> Bool
    private let now: @Sendable () -> Date
    private let names: @Sendable () -> [String: String]

    public init(reader: MessagesHistoryReader = .init(), enabled: @escaping @Sendable () -> Bool,
                now: @escaping @Sendable () -> Date = { Date() },
                names: @escaping @Sendable () -> [String: String] = { [:] }) {
        self.reader = reader
        self.enabled = enabled
        self.now = now
        self.names = names
    }

    public var definition: ToolDefinition {
        ToolDefinition(name: "messages_search", summary: "按关键词查询最近 30 天的本机短信与 iMessage（需开启 AI 短信读取及完全磁盘访问；不发送消息）",
                       inputSchema: Args.schema([
                        "query": ["type": "string", "description": "正文中的单个关键词或短语，如观鹤、报名；多个关键词分别查询"],
                        "from": Args.isoDateProp, "to": Args.isoDateProp,
                        "limit": ["type": "integer", "minimum": 1, "maximum": 50]
                       ], required: ["query"]),
                       source: .messages, effect: .read, confirmation: .never, externallyExposable: false)
    }

    public func execute(_ a: JSONValue) async throws -> AdapterOutput {
        guard enabled() else {
            throw ToolError(.sourceDisabled, "短信读取未开启。请在设置 › 数据来源开启「让 AI 读取最近 30 天的短信与 iMessage」。")
        }
        let query = try Args.requiredString(a, "query")
        guard query.count <= 100 else { throw ToolError(.invalidArguments, "短信关键词最多 100 字") }
        let end = now(), earliest = end.addingTimeInterval(-30 * 86400)
        let from = a["from"] == nil ? earliest : try Args.requiredDate(a, "from")
        let to = a["to"] == nil ? end : try Args.requiredDate(a, "to")
        guard from >= earliest, to <= end, from < to else {
            throw ToolError(.invalidArguments, "短信查询范围必须位于最近 30 天内，from 早于 to（结束时间不包含在内）。")
        }
        var limit = 20
        if let value = a["limit"] {
            guard let n = value.numberValue, n.isFinite, n.rounded() == n, (1...50).contains(n) else {
                throw ToolError(.invalidArguments, "limit 必须是 1 至 50 的整数")
            }
            limit = Int(n)
        }
        let reader = self.reader, names = self.names
        let result = try await Task.detached(priority: .userInitiated) {
            let index = names()
            var reader = reader
            reader.maxTextLength = 2000
            return try reader.search(query: query, since: from, until: to, limit: limit) {
                index[MessagesHistoryReader.normalize($0)]
            }
        }.value
        // Revocation during a query must also prevent results from reaching the model.
        guard enabled() else { throw ToolError(.sourceDisabled, "短信读取已关闭，本次结果未提供给 AI") }
        return AdapterOutput(output: [
            "application": "Apple Messages", "query": .string(query),
            "from": .string(Args.iso(from)), "to": .string(Args.iso(to)),
            "hasMore": .bool(result.hasMore), "scanLimitReached": .bool(result.scanLimitReached),
            "note": "仅查询本机已同步的信息；验证码被过滤、长数字被遮盖，正文可能为摘录。无匹配不代表所有短信均无相关内容。",
            "messages": .array(result.messages.map {
                ["id": .string($0.id), "conversation": .string($0.conversation),
                 "sender": .string($0.sender), "isFromMe": .bool($0.isFromMe),
                 "group": $0.group.map(JSONValue.string) ?? .null,
                 "date": .string(Args.iso($0.date)), "text": .string($0.text)]
            })
        ], targets: result.messages.map { TargetRef(kind: "message", identifier: $0.id) })
    }
}
