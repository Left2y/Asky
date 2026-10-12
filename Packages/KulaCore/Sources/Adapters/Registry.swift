import Foundation
import MapKit
import Contracts
import ToolService
import Memory

/// personal-context: only authorised (`.aiUse`) memory snippets, never the raw store. Not exposed to MCP.
public struct MemorySearchTool: ToolAdapter {
    let assembler: ContextAssembler
    public init(_ memories: MemoryStore) { assembler = ContextAssembler(memories: memories) }
    public var definition: ToolDefinition {
        ToolDefinition(name: "memory_search", summary: "检索用户已授权 AI 使用的个人记忆片段（推测会标注）",
                       inputSchema: Args.schema(["query": Args.stringProp], required: ["query"]),
                       source: .memory, effect: .read, confirmation: .never, externallyExposable: false)
    }
    public func execute(_ a: JSONValue) async throws -> AdapterOutput {
        let s = assembler.snippets(for: try Args.requiredString(a, "query"))
        return AdapterOutput(output: .array(s.map { ["source": .string($0.sourceID), "text": .string($0.text)] }))
    }
}

private func memoryID(_ a: JSONValue) throws -> String {
    let raw = try Args.requiredString(a, "id")
    return raw.hasPrefix("memory:") ? String(raw.dropFirst(7)) : raw
}

private func activeMemory(_ memories: MemoryStore, _ a: JSONValue) throws -> MemoryRecord {
    guard let m = memories.get(try memoryID(a)), m.status == .active else {
        throw ToolError(.targetNotFound, "找不到这条记忆，请先用 memory_search 查到它的 id")
    }
    return m
}

/// Saves something the user explicitly asked Asky to remember. Inferred saves only become suggestions.
public struct MemorySaveTool: ToolAdapter {
    static let kinds: [String: MemoryKind] = ["fact": .fact, "preference": .preference, "episode": .episode]
    let memories: MemoryStore
    public init(_ memories: MemoryStore) { self.memories = memories }
    public var definition: ToolDefinition {
        ToolDefinition(name: "memory_save", summary: "保存用户明确要求记住的信息为长期记忆",
                       inputSchema: Args.schema([
                        "content": ["type": "string", "description": "一句完整、可独立理解的陈述，例如「用户的常用机场是浦东」"],
                        "kind": ["type": "string", "enum": ["fact", "preference", "episode"],
                                 "description": "fact 事实；preference 偏好；episode 近期项目、讨论或决定"],
                        "subjects": ["type": "array", "items": ["type": "string"], "description": "相关的人、项目或主题"],
                       ], required: ["content", "kind"]),
                       source: .memory, effect: .write, writeKind: .create, confirmation: .createDirectOtherwiseConfirm,
                       externallyExposable: false)
    }
    public func preview(_ a: JSONValue) async throws -> ConfirmationPreview {
        ConfirmationPreview(target: "长期记忆", changes: ["保存：" + String(try Args.requiredString(a, "content").prefix(300))])
    }
    public func execute(_ a: JSONValue) async throws -> AdapterOutput {
        let content = try Args.requiredString(a, "content")
        guard content.count <= 500 else { throw ToolError(.invalidArguments, "记忆内容过长，请精简为一句话") }
        guard let kind = Self.kinds[a["kind"]?.stringValue ?? ""] else { throw ToolError(.invalidArguments, "kind 无效") }
        let subjects = (a["subjects"]?.arrayValue ?? []).compactMap(\.stringValue).prefix(8)
        let m = try memories.saveStated(content, kind: kind, subjects: Array(subjects))
        return AdapterOutput(output: ["id": .string("memory:\(m.id)")], targets: [TargetRef(kind: "memory", identifier: m.id)])
    }
    public func readback(_ a: JSONValue, output: AdapterOutput?) async -> JSONValue? {
        guard let id = output?.targets.first?.identifier, memories.get(id)?.status == .active else { return nil }
        return ["id": .string("memory:\(id)"), "saved": true]
    }
}

/// User correction of an existing memory; the old record stays traceable but inactive.
/// Memory edits are reversible from settings, so an explicit user request runs without an extra prompt.
public struct MemoryCorrectTool: ToolAdapter {
    let memories: MemoryStore
    public init(_ memories: MemoryStore) { self.memories = memories }
    public var definition: ToolDefinition {
        ToolDefinition(name: "memory_correct", summary: "按用户的纠正更新一条已有记忆",
                       inputSchema: Args.schema(["id": ["type": "string", "description": "memory_search 返回的 source，如 memory:xxx"],
                                                 "content": Args.stringProp], required: ["id", "content"]),
                       source: .memory, effect: .write, writeKind: .modify, confirmation: .explicitDirectOtherwiseConfirm,
                       externallyExposable: false)
    }
    public func preview(_ a: JSONValue) async throws -> ConfirmationPreview {
        let m = try activeMemory(memories, a)
        return ConfirmationPreview(target: "记忆「\(m.content.prefix(80))」",
                                   changes: ["改为：" + String(try Args.requiredString(a, "content").prefix(300))])
    }
    public func execute(_ a: JSONValue) async throws -> AdapterOutput {
        let old = try activeMemory(memories, a)
        guard let m = try memories.correct(old.id, newContent: try Args.requiredString(a, "content")) else {
            throw ToolError(.targetNotFound, "找不到这条记忆")
        }
        return AdapterOutput(output: ["id": .string("memory:\(m.id)")], targets: [TargetRef(kind: "memory", identifier: m.id)])
    }
    public func readback(_ a: JSONValue, output: AdapterOutput?) async -> JSONValue? {
        guard let id = output?.targets.first?.identifier, memories.get(id)?.status == .active else { return nil }
        return ["id": .string("memory:\(id)"), "corrected": true]
    }
}

/// Deletes a memory the user asked Asky to forget.
public struct MemoryForgetTool: ToolAdapter {
    let memories: MemoryStore
    public init(_ memories: MemoryStore) { self.memories = memories }
    public var definition: ToolDefinition {
        ToolDefinition(name: "memory_forget", summary: "删除用户要求忘记的一条记忆",
                       inputSchema: Args.schema(["id": ["type": "string", "description": "memory_search 返回的 source，如 memory:xxx"]],
                                                required: ["id"]),
                       source: .memory, effect: .write, writeKind: .delete, confirmation: .explicitDirectOtherwiseConfirm,
                       externallyExposable: false)
    }
    public func preview(_ a: JSONValue) async throws -> ConfirmationPreview {
        let m = try activeMemory(memories, a)
        return ConfirmationPreview(target: "记忆「\(m.content.prefix(80))」", changes: ["删除这条记忆"])
    }
    public func execute(_ a: JSONValue) async throws -> AdapterOutput {
        let m = try activeMemory(memories, a)
        try memories.delete(m.id)
        return AdapterOutput(output: ["deleted": true], targets: [TargetRef(kind: "memory", identifier: m.id)])
    }
    public func readback(_ a: JSONValue, output: AdapterOutput?) async -> JSONValue? {
        guard let id = try? memoryID(a), memories.get(id) == nil else { return nil }
        return ["deleted": true]
    }
}

/// Route ETA via MapKit. Returns nil when the location or route cannot be resolved — callers must not invent a time.
public enum RouteETA {
    public static func eta(to address: String, transport: MKDirectionsTransportType = .automobile,
                           arrival: Date? = nil) async -> TimeInterval? {
        let dest: MKMapItem
        if #available(macOS 26, *) {
            guard let req = MKGeocodingRequest(addressString: address),
                  let item = try? await req.mapItems.first else { return nil }
            dest = item
        } else {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = address
            guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
            dest = item
        }
        let r = MKDirections.Request()
        r.source = MKMapItem.forCurrentLocation()
        r.destination = dest
        r.transportType = transport
        if let arrival { r.arrivalDate = arrival }
        return try? await MKDirections(request: r).calculateETA().expectedTravelTime
    }
}

/// All native tool adapters, wired once by the App.
public struct NativeTools: Sendable {
    public let eventKit = EventKitBridge()
    public let contacts = ContactsBridge()
    public let chrome = ChromeBridge()
    public let notes: NotesBridge
    private let messagesEnabled: @Sendable () -> Bool

    public init(notesFolders: @escaping @Sendable () -> [NotesFolder],
                messagesEnabled: @escaping @Sendable () -> Bool = { false }) {
        self.messagesEnabled = messagesEnabled
        notes = NotesBridge(allowed: notesFolders)
    }

    public func adapters(memories: MemoryStore?) -> [any ToolAdapter] {
        var all: [any ToolAdapter] = [
            CalendarListTool(eventKit), CalendarSearchTool(eventKit), CalendarCreateTool(eventKit), CalendarUpdateTool(eventKit), CalendarDeleteTool(eventKit),
            RemindersListTool(eventKit), RemindersCreateTool(eventKit),
            NotesListFoldersTool(notes), NotesSearchTool(notes), NotesReadTool(notes), NotesCreateTool(notes), NotesAppendTool(notes),
            ContactsSearchTool(contacts), MessagesDraftTool(contacts),
            MessagesSearchTool(enabled: messagesEnabled),
            ChromeListTabsTool(chrome), ChromeActivateTabTool(chrome),
            ShortcutsListTool(), ShortcutsRunTool(), WebSearchTool(),
        ]
        if let memories {
            all += [MemorySearchTool(memories), MemorySaveTool(memories), MemoryCorrectTool(memories), MemoryForgetTool(memories)] as [any ToolAdapter]
        }
        return all
    }

    public func register(into service: ToolService, memories: MemoryStore?) async {
        for a in adapters(memories: memories) { await service.register(a) }
    }
}
