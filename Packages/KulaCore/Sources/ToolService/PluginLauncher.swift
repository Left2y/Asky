import Foundation
import AppKit
import Contracts

extension ToolService {
    /// Resolve the installed command afresh. Callers cannot supply a tool or execution policy.
    public func runPluginCommand(id: String, query: String) async -> ExecutionResult {
        guard let entry = await plugins.launcherCommands().first(where: { $0.id == id }) else {
            return .failure(UUID().uuidString, .sourceDisabled, CoreLocalization.text("插件已停用或正在更新"))
        }
        let arguments: JSONValue = entry.command.queryArgument.map { .object([$0: .string(query)]) } ?? [:]
        return await submit(ActionRequest(tool: "plugin_\(entry.pluginID)__\(entry.command.tool)",
                                          arguments: arguments, origin: .launcher, intent: .explicitRequest))
    }

    @MainActor public static func copyPluginText(_ text: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }
}

/// Bounded native presentation; no HTML, script or arbitrary host action is interpreted.
public enum PluginLauncherOutput {
    public static func results(_ output: JSONValue, commandID: String) throws -> [SearchResult] {
        if let text = output["text"]?.stringValue, output["items"] == nil {
            return [SearchResult(source: .keyword, target: TargetRef(kind: "plugin-result", identifier: commandID + "/text"),
                                 title: text, actions: [.copy(text)], score: 100)]
        }
        guard let items = output["items"]?.arrayValue else {
            throw ToolError(.adapterFailure, CoreLocalization.text("插件结果必须包含文本或列表"))
        }
        var ids = Set<String>()
        return try items.prefix(200).map { item in
            guard let id = item["id"]?.stringValue, !id.isEmpty, ids.insert(id).inserted,
                  let title = item["title"]?.stringValue, !title.isEmpty else {
                throw ToolError(.adapterFailure, CoreLocalization.text("插件结果格式无效"))
            }
            var actions: [ResultAction] = []
            if let text = item["copy"]?.stringValue { actions.append(.copy(text)) }
            if let value = item["url"]?.stringValue {
                guard let url = URL(string: value), let scheme = url.scheme?.lowercased(),
                      ["https", "http"].contains(scheme), url.host?.isEmpty == false,
                      url.user == nil, url.password == nil else {
                    throw ToolError(.adapterFailure, CoreLocalization.text("插件结果链接必须使用 HTTP 或 HTTPS"))
                }
                actions.append(.openURL(url))
            }
            return SearchResult(source: .keyword, target: TargetRef(kind: "plugin-result", identifier: commandID + "/" + id),
                                title: title, subtitle: item["subtitle"]?.stringValue ?? "", actions: actions, score: 100)
        }
    }
}
