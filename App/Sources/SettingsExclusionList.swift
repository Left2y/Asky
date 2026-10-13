import SwiftUI
import ToolService

/// Adds exclusions through a picker and removes them individually.
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
            VStack(alignment: .leading, spacing: 6) {
                if items.isEmpty {
                    Text(NSLocalizedString("暂无排除项", comment: "")).foregroundStyle(.secondary)
                }
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Text(item)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(item)
                            .textSelection(.enabled)
                        Spacer(minLength: 12)
                        SettingsButton(NSLocalizedString("删除", comment: ""), role: .destructive) {
                            items.remove(at: index)
                        }
                        .accessibilityLabel(NSLocalizedString("删除", comment: "") + " " + item)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.vertical, 4)
        .disabled(choosing)
    }

    private func choose() {
        choosing = true
        Task { @MainActor in
            defer { choosing = false }
            guard let value = await ToolService.chooseSettingsExclusion(selection), !items.contains(value) else { return }
            items.append(value)
        }
    }
}
