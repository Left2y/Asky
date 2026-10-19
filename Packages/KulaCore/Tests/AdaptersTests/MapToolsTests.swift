import Foundation
import Testing
import Contracts
import LocalStore
import ToolService
@testable import Adapters

private actor FakeMapClient: MapClient {
    var requests: [(String, Date?, Date?)] = []
    var failing: Set<String>
    init(failing: Set<String> = []) { self.failing = failing }
    func search(_ query: String, limit: Int) async throws -> [MapPlace] {
        [MapPlace(name: query, address: "Shanghai", latitude: 31.2, longitude: 121.4)]
    }
    func estimate(from: MapPlace, to: MapPlace, mode: String, departure: Date?, arrival: Date?) async throws -> MapEstimate {
        requests.append((mode, departure, arrival))
        if failing.contains(mode) { throw ToolError(.unavailable, "No route") }
        return MapEstimate(seconds: 1800, meters: 10000)
    }
}

@Suite struct MapToolsTests {
    let origin: JSONValue = ["name": "Origin", "latitude": 31.2, "longitude": 121.3]
    let destination: JSONValue = ["name": "Destination", "latitude": 31.3, "longitude": 121.4]

    @Test func arrivalIncludesBufferOnceAndKeepsAvailableModes() async throws {
        let client = FakeMapClient(failing: ["transit"])
        let target = try #require(Args.date("2030-10-19T10:00:00+08:00".json))
        let output = try await MapsRoutesTool(client: client).execute([
            "origin": origin, "destination": destination, "arrivalTime": "2030-10-19T10:00:00+08:00", "bufferMinutes": 15
        ]).output
        let routes = try #require(output["routes"]?.arrayValue)
        #expect(routes.count == 2)
        #expect(routes.map { $0["mode"]?.stringValue } == ["driving", "walking"])
        #expect(output["unavailableModes"]?.arrayValue?.first?["mode"] == "transit")
        for route in routes {
            #expect(Args.date(route["suggestedDepartureTime"]) == target.addingTimeInterval(-45 * 60))
            #expect(Args.date(route["estimatedArrivalTime"]) == target.addingTimeInterval(-15 * 60))
            #expect(route["detailsAvailable"] == false)
        }
        let requests = await client.requests
        #expect(requests.count == 3)
        #expect(requests.allSatisfy { $0.1 == nil && $0.2 == target.addingTimeInterval(-15 * 60) })
    }

    @Test func departureDoesNotInventAnEarlierStart() async throws {
        let client = FakeMapClient()
        let date = try #require(Args.date("2030-10-19T09:00:00+08:00".json))
        let output = try await MapsRoutesTool(client: client).execute([
            "origin": origin, "destination": destination, "departureTime": "2030-10-19T09:00:00+08:00", "modes": ["walking"]
        ]).output
        let route = try #require(output["routes"]?.arrayValue?.first)
        #expect(Args.date(route["suggestedDepartureTime"]) == date)
        #expect(Args.date(route["estimatedArrivalTime"]) == date.addingTimeInterval(1800))
        #expect(await client.requests.first?.2 == nil)
    }

    @Test func rejectsInvalidLocationsModesAndTimesBeforeQuery() async {
        let client = FakeMapClient()
        let base: [String: JSONValue] = ["origin": origin, "destination": destination]
        let changes: [[String: JSONValue]] = [
            ["origin": ["name": "Unknown", "latitude": 91, "longitude": 0]],
            ["destination": ["name": "No coordinates"]],
            ["modes": ["taxi"]], ["modes": ["walking", "walking"]], ["modes": []],
            ["departureTime": "bad"], ["departureTime": "2030-10-19", "arrivalTime": "2030-10-19"],
            ["bufferMinutes": -1], ["bufferMinutes": 1.5]
        ]
        for change in changes {
            do {
                _ = try await MapsRoutesTool(client: client).execute(.object(base.merging(change) { _, new in new }))
                Issue.record("Accepted malformed route arguments")
            } catch let e as ToolError { #expect(e.code == .invalidArguments) }
            catch { Issue.record("Unexpected \(error)") }
        }
        #expect(await client.requests.isEmpty)
        for value: JSONValue in [["query": " "], ["query": "Shanghai", "limit": 6], ["query": "Shanghai", "limit": 1.5]] {
            await #expect(throws: ToolError.self) { try await MapsSearchPlacesTool(client: client).execute(value) }
        }
    }

    @Test func allUnavailableIsFailureAndCancellationIsNotAnEstimate() async {
        let client = FakeMapClient(failing: ["driving", "walking", "transit"])
        await #expect(throws: ToolError.self) {
            try await MapsRoutesTool(client: client).execute(["origin": origin, "destination": destination])
        }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await MapsRoutesTool(client: client).execute(["origin": origin, "destination": destination])
        }
        do { _ = try await task.value; Issue.record("Cancellation accepted") }
        catch { #expect(error is CancellationError) }
    }

    @Test func mapsSwitchControlsDiscoveryAndExecutionWithoutWeb() async throws {
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        for enabled in [false, true] {
            let service = ToolService(store: store, policy: { PolicySnapshot(enabledSources: enabled ? [.maps] : []) }, presenter: { _ in .rejected })
            await service.register(MapsSearchPlacesTool(client: FakeMapClient()))
            await service.register(MapsRoutesTool(client: FakeMapClient()))
            let names = await service.definitions(for: .agent(sessionID: "s")).map(\.name)
            #expect(Set(names) == (enabled ? Set(["maps_search_places", "maps_routes"]) : []))
            #expect(await service.definitions(for: .mcp(instanceID: "s")).isEmpty)
            let result = await service.submit(ActionRequest(tool: "maps_search_places", arguments: ["query": "Shanghai"], origin: .agent(sessionID: "s"), intent: .explicitRequest))
            if enabled {
                #expect(result.status == .completed)
                #expect(result.output?["places"]?.arrayValue?.count == 1)
            } else { #expect(result.error?.code == .sourceDisabled) }
        }
    }

    @Test func liveMapKitThroughToolService() async throws {
        guard ProcessInfo.processInfo.environment["ASKY_LIVE_MAPS"] == "1" else { return }
        let store = try LocalStore(inMemoryWithRoot: FileManager.default.temporaryDirectory)
        let service = ToolService(store: store, policy: { PolicySnapshot(enabledSources: [.maps]) }, presenter: { _ in .rejected })
        await service.register(MapsSearchPlacesTool())
        await service.register(MapsRoutesTool())
        var places: [JSONValue] = []
        for query in ["上海市虹桥火车站", "上海市静安寺", "上海市东方明珠广播电视塔"] {
            let result = await service.submit(ActionRequest(tool: "maps_search_places", arguments: ["query": .string(query)], origin: .agent(sessionID: "live"), intent: .explicitRequest))
            #expect(result.status == .completed, "\(String(describing: result.error))")
            let place = try #require(result.output?["places"]?.arrayValue?.first)
            places.append(place)
            print("LIVE MAP SEARCH \(String(data: result.output!.canonicalData(), encoding: .utf8)!)")
        }
        for i in 0..<2 {
            let result = await service.submit(ActionRequest(tool: "maps_routes", arguments: ["origin": places[i], "destination": places[i+1]], origin: .agent(sessionID: "live"), intent: .explicitRequest))
            #expect(result.status == .completed, "\(String(describing: result.error))")
            let routes = try #require(result.output?["routes"]?.arrayValue)
            #expect(Set(routes.compactMap { $0["mode"]?.stringValue }) == ["driving", "transit", "walking"])
            #expect(routes.allSatisfy { ($0["durationSeconds"]?.numberValue ?? 0) > 0 })
            print("LIVE MAP ROUTES \(String(data: result.output!.canonicalData(), encoding: .utf8)!)")
        }
        let arrival = Date().addingTimeInterval(2 * 3600)
        let timed = await service.submit(ActionRequest(tool: "maps_routes", arguments: [
            "origin": places[0], "destination": places[1], "arrivalTime": .string(Args.iso(arrival)),
            "modes": ["driving", "transit"], "bufferMinutes": 10
        ], origin: .agent(sessionID: "live"), intent: .explicitRequest))
        #expect(timed.status == .completed, "\(String(describing: timed.error))")
        let timedRoutes = try #require(timed.output?["routes"]?.arrayValue)
        #expect(!timedRoutes.isEmpty)
        for route in timedRoutes {
            let estimated = try #require(Args.date(route["estimatedArrivalTime"]))
            #expect(abs(estimated.timeIntervalSince(arrival.addingTimeInterval(-600))) < 2)
        }
        print("LIVE MAP ARRIVAL \(String(data: timed.output!.canonicalData(), encoding: .utf8)!)")
    }
}

private extension String { var json: JSONValue { .string(self) } }
