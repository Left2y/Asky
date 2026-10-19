import Foundation
import MapKit
import Contracts
import ToolService

struct MapPlace: Sendable {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double

    var json: JSONValue {
        ["name": .string(name), "address": .string(address),
         "latitude": .number(latitude), "longitude": .number(longitude)]
    }

    static let schema = Args.schema([
        "name": Args.stringProp, "address": Args.stringProp,
        "latitude": ["type": "number", "minimum": -90, "maximum": 90],
        "longitude": ["type": "number", "minimum": -180, "maximum": 180]
    ], required: ["name", "latitude", "longitude"])

    static func parse(_ value: JSONValue?, field: String) throws -> MapPlace {
        guard let value, let name = value["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty, name.count <= 300,
              let lat = value["latitude"]?.numberValue, lat.isFinite, (-90...90).contains(lat),
              let lon = value["longitude"]?.numberValue, lon.isFinite, (-180...180).contains(lon) else {
            throw ToolError(.invalidArguments, CoreLocalization.format("%@ 必须包含地点名称及有效经纬度，请使用地点搜索结果", field))
        }
        return MapPlace(name: name, address: String((value["address"]?.stringValue ?? "").prefix(500)), latitude: lat, longitude: lon)
    }
}

struct MapEstimate: Sendable {
    var seconds: Double
    var meters: Double
}

protocol MapClient: Sendable {
    func search(_ query: String, limit: Int) async throws -> [MapPlace]
    func estimate(from: MapPlace, to: MapPlace, mode: String, departure: Date?, arrival: Date?) async throws -> MapEstimate
}

/// Only the native ToolService adapters access MapKit. No implicit current-location lookup.
struct NativeMapClient: MapClient {
    @MainActor func search(_ query: String, limit: Int) async throws -> [MapPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        return try await withTaskCancellationHandler {
            let response = try await search.start()
            return response.mapItems.prefix(limit).map {
                MapPlace(name: $0.name ?? query, address: $0.placemark.title ?? "",
                         latitude: $0.placemark.coordinate.latitude, longitude: $0.placemark.coordinate.longitude)
            }
        } onCancel: { search.cancel() }
    }

    @MainActor func estimate(from: MapPlace, to: MapPlace, mode: String, departure: Date?, arrival: Date?) async throws -> MapEstimate {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: from.latitude, longitude: from.longitude)))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: to.latitude, longitude: to.longitude)))
        request.source?.name = from.name
        request.destination?.name = to.name
        request.transportType = mode == "transit" ? .transit : mode == "walking" ? .walking : .automobile
        request.departureDate = departure
        request.arrivalDate = arrival
        let directions = MKDirections(request: request)
        return try await withTaskCancellationHandler {
            let response = try await directions.calculateETA()
            guard response.transportType == request.transportType else {
                throw ToolError(.unavailable, CoreLocalization.text("该交通方式暂无可用路线时间"))
            }
            return MapEstimate(seconds: response.expectedTravelTime, meters: response.distance)
        } onCancel: { directions.cancel() }
    }
}

private func mapRequest<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(20))
            throw ToolError(.timeout, CoreLocalization.text("地图查询超时，请稍后重试"))
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

public struct MapsSearchPlacesTool: ToolAdapter {
    public var executionTimeout: Duration? { .seconds(25) }
    let client: any MapClient
    public init() { client = NativeMapClient() }
    init(client: any MapClient) { self.client = client }

    public var definition: ToolDefinition {
        ToolDefinition(name: "maps_search_places", summary: CoreLocalization.text("使用 Apple MapKit 搜索地点，返回名称、地址和坐标候选；包含城市以消除歧义，不要猜坐标"),
            inputSchema: Args.schema(["query": Args.stringProp, "limit": ["type": "integer", "minimum": 1, "maximum": 5]], required: ["query"]),
            source: .maps, effect: .read, confirmation: .never, externallyExposable: false)
    }

    public func execute(_ arguments: JSONValue) async throws -> AdapterOutput {
        let query = try Args.requiredString(arguments, "query")
        guard query.count <= 300 else { throw ToolError(.invalidArguments, CoreLocalization.text("地点搜索词不能超过 300 字")) }
        let limit: Int
        if let value = arguments["limit"] {
            guard let n = value.numberValue, n.isFinite, n.rounded() == n, (1...5).contains(n) else {
                throw ToolError(.invalidArguments, CoreLocalization.text("limit 必须是 1 到 5 的整数"))
            }
            limit = Int(n)
        } else { limit = 5 }
        do {
            let places = try await mapRequest { try await client.search(query, limit: limit) }
            return AdapterOutput(output: ["provider": "Apple MapKit", "query": .string(query),
                "retrievedAt": .string(Args.iso(Date())), "places": .array(places.map(\.json)),
                "guidance": .string(CoreLocalization.text("核对地点地址；有歧义时请用户选择，不能默认第一项就是目标"))])
        } catch is CancellationError { throw CancellationError() }
        catch let error as ToolError { throw error }
        catch { throw ToolError(.unavailable, CoreLocalization.text("地图地点搜索失败，请补充城市或完整地址后重试")) }
    }
}

public struct MapsRoutesTool: ToolAdapter {
    public var executionTimeout: Duration? { .seconds(65) }
    let client: any MapClient
    public init() { client = NativeMapClient() }
    init(client: any MapClient) { self.client = client }

    public var definition: ToolDefinition {
        ToolDefinition(name: "maps_routes", summary: CoreLocalization.text("使用 Apple MapKit 比较明确起终点的驾车、公交、步行耗时；可指定出发或到达时间，返回含缓冲的建议出发时间；公交仅有耗时，无线路换乘详情"),
            inputSchema: Args.schema([
                "origin": MapPlace.schema, "destination": MapPlace.schema,
                "modes": ["type": "array", "minItems": 1, "maxItems": 3, "uniqueItems": true,
                          "items": ["type": "string", "enum": ["driving", "transit", "walking"]]],
                "departureTime": Args.isoDateProp, "arrivalTime": Args.isoDateProp,
                "bufferMinutes": ["type": "integer", "minimum": 0, "maximum": 120]
            ], required: ["origin", "destination"]),
            source: .maps, effect: .read, confirmation: .never, externallyExposable: false)
    }

    public func execute(_ arguments: JSONValue) async throws -> AdapterOutput {
        let from = try MapPlace.parse(arguments["origin"], field: "origin")
        let to = try MapPlace.parse(arguments["destination"], field: "destination")
        let modes: [String]
        if let supplied = arguments["modes"] {
            guard let array = supplied.arrayValue, (1...3).contains(array.count) else { throw ToolError(.invalidArguments, CoreLocalization.text("modes 必须包含 1 到 3 种交通方式")) }
            let strings = array.compactMap(\.stringValue)
            guard strings.count == array.count, Set(strings).count == strings.count,
                  strings.allSatisfy({ ["driving", "transit", "walking"].contains($0) }) else {
                throw ToolError(.invalidArguments, CoreLocalization.text("交通方式只能是 driving、transit、walking，且不能重复"))
            }
            modes = strings
        } else { modes = ["driving", "transit", "walking"] }
        let departure = try arguments["departureTime"].map { _ in try Args.requiredDate(arguments, "departureTime") }
        let arrival = try arguments["arrivalTime"].map { _ in try Args.requiredDate(arguments, "arrivalTime") }
        guard departure == nil || arrival == nil else { throw ToolError(.invalidArguments, CoreLocalization.text("出发时间和到达时间只能指定一个")) }
        let buffer: Double
        if let value = arguments["bufferMinutes"] {
            guard let n = value.numberValue, n.isFinite, n.rounded() == n, (0...120).contains(n) else { throw ToolError(.invalidArguments, CoreLocalization.text("缓冲时间必须是 0 到 120 的整数分钟")) }
            buffer = n
        } else { buffer = 10 }
        let now = Date()
        let routeArrival = arrival?.addingTimeInterval(-buffer * 60)
        var routes: [JSONValue] = []
        var failures: [JSONValue] = []
        for mode in modes {
            try Task.checkCancellation()
            do {
                let estimate = try await mapRequest {
                    try await client.estimate(from: from, to: to, mode: mode,
                                              departure: departure ?? (arrival == nil ? now : nil), arrival: routeArrival)
                }
                guard estimate.seconds.isFinite, estimate.seconds > 0, estimate.meters.isFinite, estimate.meters >= 0 else {
                    throw ToolError(.unavailable, CoreLocalization.text("MapKit 返回的路线耗时无效"))
                }
                let leave = routeArrival?.addingTimeInterval(-estimate.seconds) ?? departure ?? now
                routes.append(["mode": .string(mode), "durationSeconds": .number(estimate.seconds),
                    "distanceMeters": .number(estimate.meters), "suggestedDepartureTime": .string(Args.iso(leave)),
                    "estimatedArrivalTime": .string(Args.iso(leave.addingTimeInterval(estimate.seconds))),
                    "departureAlreadyPassed": .bool(leave < now), "bufferMinutes": .number(buffer),
                    "detailsAvailable": false])
            } catch is CancellationError { throw CancellationError() }
            catch {
                try Task.checkCancellation()
                failures.append(["mode": .string(mode), "error": .string((error as? ToolError)?.message ?? CoreLocalization.text("该交通方式暂无可用路线时间"))])
            }
        }
        guard !routes.isEmpty else { throw ToolError(.unavailable, CoreLocalization.text("暂无可用路线时间，不能生成具体出发建议，请稍后重试")) }
        return AdapterOutput(output: ["provider": "Apple MapKit", "retrievedAt": .string(Args.iso(now)),
            "origin": from.json, "destination": to.json,
            "requestedDepartureTime": departure.map { .string(Args.iso($0)) } ?? .null,
            "requestedArrivalTime": arrival.map { .string(Args.iso($0)) } ?? .null,
            "routes": .array(routes), "unavailableModes": .array(failures),
            "guidance": .string(CoreLocalization.text("耗时为估计，临近出发需刷新；不包含停车或打车等候时间，不提供公交线路与换乘详情；不能把驾车耗时当成打车总耗时"))])
    }
}
