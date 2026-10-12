import Foundation
import Testing
import Contracts
import LocalStore
import ToolService
@testable import Adapters

@Suite struct NotesFolderTests {
    @Test func legacySelectionsDecodeAndMatchDiscovery() throws {
        let old = try JSONDecoder().decode(NotesFolder.self, from: Data(#"{"account":"iCloud","folder":"备忘录"}"#.utf8))
        let discovered = NotesFolder(account: "iCloud", folder: "备忘录", folderID: "folder-id")
        #expect(old.folderID == nil)
        #expect(old.matchesLocation(discovered))
        #expect(old != discovered) // Identifier migration must trigger settings persistence.
        #expect(Set([old, discovered]).count == 2)
        #expect(discovered.scriptRef == "folder id \"folder-id\"")
        #expect(old.scriptRef == "folder \"备忘录\" of account \"iCloud\"")
        #expect(try JSONDecoder().decode(NotesFolder.self, from: JSONEncoder().encode(discovered)).folderID == "folder-id")
        #expect(NotesFolder(account: "iCloud", folder: "Parent / Child", folderID: "nested-id").scriptRef == "folder id \"nested-id\"")
    }

    @Test func discoveryCannotBeUsedByAIOrMCP() async throws {
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let service = ToolService(store: store, policy: {
            PolicySnapshot(enabledSources: [.notes], mcpInstances: ["test": MCPInstance(id: "test", name: "test", enabled: true, sources: [.notes])])
        }, presenter: { _ in .rejected })
        await service.register(NotesListFoldersTool(NotesBridge(allowed: { [] })))
        #expect(await service.definitions(for: .launcher).contains { $0.name == "notes_list_folders" })
        #expect(await service.definitions(for: .agent(sessionID: "test")).isEmpty)
        #expect(await service.definitions(for: .mcp(instanceID: "test")).isEmpty)
        for origin in [CallerOrigin.agent(sessionID: "test"), .mcp(instanceID: "test")] {
            let result = await service.submit(ActionRequest(tool: "notes_list_folders", arguments: .object([:]), origin: origin, intent: .explicitRequest))
            #expect(result.error?.code == .notExposed)
        }
        #expect(throws: ToolError.self) { try NotesBridge(allowed: { [] }).folders() }
    }
}
