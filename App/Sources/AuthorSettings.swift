import SwiftUI
import ToolService

struct AuthorSettings: View {
    @State private var openingFailed = false

    var body: some View {
        Form {
            Section(NSLocalizedString("关于作者", comment: "")) {
                LabeledContent(NSLocalizedString("作者", comment: "")) {
                    Text(verbatim: "Niall Young").textSelection(.enabled)
                }
                Text(NSLocalizedString("欢迎联系我，反馈问题或分享建议。", comment: ""))
                    .foregroundStyle(.secondary)
            }
            Section(NSLocalizedString("联系与反馈", comment: "")) {
                LabeledContent(NSLocalizedString("邮箱", comment: "")) {
                    Link("niallyoung2002@gmail.com", destination: URL(string: "mailto:niallyoung2002@gmail.com")!)
                }
                LabeledContent("GitHub") {
                    Link("github.com/Niall-Young", destination: URL(string: "https://github.com/Niall-Young")!)
                }
                LabeledContent("X") {
                    Link("x.com/NiallxYoung", destination: URL(string: "https://x.com/NiallxYoung")!)
                }
                if openingFailed {
                    Text(NSLocalizedString("无法打开链接，请检查默认浏览器或邮件应用。", comment: ""))
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .environment(\.openURL, OpenURLAction { url in
            openingFailed = !ToolService.openLauncherURL(url)
            return openingFailed ? .discarded : .handled
        })
    }
}
