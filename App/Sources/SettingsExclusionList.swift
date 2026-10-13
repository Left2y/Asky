import SwiftUI
import ToolService

/// Edits one stored exclusion at a time; drafts never change the saved settings.
struct SettingsExclusionList: View {
    let title: String
    let selection: SettingsExclusionSelection
    @Binding var items: [String]
    @State private var choosing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                Spacer()
                SettingsButton(NSLocalizedString("添加", comment: ""), systemImage: "plus") {
                    choose()
                }
                .accessibilityLabel(NSLocalizedString("添加", comment: "") + " " + title)
            }
            if items.isEmpty {
                Text(NSLocalizedString("暂无排除项", comment: "")).foregroundStyle(.secondary)
            }
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider() }
                HStack(spacing: 12) {
                    Text(item)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(item)
                        .textSelection(.enabled)
                    Spacer(minLength: 12)
                    SettingsButton(NSLocalizedString("编辑", comment: "")) {
                        choose(replacing: index)
                    }
                    .accessibilityLabel(NSLocalizedString("编辑", comment: "") + " " + item)
                    SettingsButton(NSLocalizedString("删除", comment: ""), role: .destructive) {
                        items.remove(at: index)
                    }
                    .accessibilityLabel(NSLocalizedString("删除", comment: "") + " " + item)
                }
            }
        }
        .disabled(choosing)
    }

    private func choose(replacing index: Int? = nil) {
        choosing = true
        // Remember the original item so a concurrent change cannot replace a different row.
        let original = index.map { items[$0] }
        Task { @MainActor in
            defer { choosing = false }
            guard let value = await ToolService.chooseSettingsExclusion(selection) else { return }
            if let index, let original {
                guard items.indices.contains(index), items[index] == original,
                      !items.enumerated().contains(where: { $0.offset != index && $0.element == value }) else { return }
                items[index] = value
            } else if !items.contains(value) {
                items.append(value)
            }
        }
    }
}
