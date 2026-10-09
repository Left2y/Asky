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

/// Route ETA via MapKit. Returns nil when the location or route cannot be resolved — callers must not invent a time.
public enum RouteETA {
    public static func eta(to address: String, transport: MKDirectionsTransportType = .automobile,
                           arrival: Date? = nil) async -> TimeInterval? {
        guard let req = MKGeocodingRequest(addressString: address),
              let dest = try? await req.mapItems.first else { return nil }
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

    public init(notesFolders: @escaping @Sendable () -> [NotesFolder]) {
        notes = NotesBridge(allowed: notesFolders)
    }

    public func adapters(memories: MemoryStore?) -> [any ToolAdapter] {
        var all: [any ToolAdapter] = [
            CalendarSearchTool(eventKit), CalendarCreateTool(eventKit), CalendarUpdateTool(eventKit), CalendarDeleteTool(eventKit),
            RemindersListTool(eventKit), RemindersCreateTool(eventKit),
            NotesSearchTool(notes), NotesReadTool(notes), NotesCreateTool(notes), NotesAppendTool(notes),
            ContactsSearchTool(contacts), MessagesDraftTool(contacts),
            ChromeListTabsTool(chrome), ChromeActivateTabTool(chrome),
            ShortcutsListTool(), ShortcutsRunTool(),
        ]
        if let memories { all.append(MemorySearchTool(memories)) }
        return all
    }

    public func register(into service: ToolService, memories: MemoryStore?) async {
        for a in adapters(memories: memories) { await service.register(a) }
    }
}
