import SwiftUI
import Theme
import ToolService

struct AboutSettings: View {
    private enum Status: Equatable {
        case idle, checking, upToDate, available(AppRelease), installing(String), failed(String)
    }

    @State private var status = Status.idle
    @State private var confirmingInstall = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image("AskyLogo").resizable().scaledToFit().frame(width: 56, height: 56).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "Asky").font(.title2.weight(.semibold))
                        Text(ToolService.currentAppBuild.isEmpty
                             ? String(format: NSLocalizedString("版本 %@", comment: ""), ToolService.currentAppVersion)
                             : String(format: NSLocalizedString("版本 %@（%@）", comment: ""),
                                      ToolService.currentAppVersion, ToolService.currentAppBuild))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4)
                Link(NSLocalizedString("在 GitHub 查看项目", comment: ""), destination: ToolService.appRepositoryURL)
            }
            Section(NSLocalizedString("软件更新", comment: "")) {
                HStack {
                    statusText
                    Spacer(minLength: 12)
                    actionButton
                }
                Text(NSLocalizedString("从 GitHub Releases 获取最新版本。安装时会下载并校验新版本，退出 Asky 后替换当前应用并删除旧版本，然后自动重新打开。", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(NSLocalizedString("安装新版本？", comment: ""), isPresented: $confirmingInstall) {
            if case .available(let release) = status {
                Button(NSLocalizedString("安装并重新打开", comment: "")) { Task { await install(release) } }
            }
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("Asky 将退出，用新版本替换并删除当前版本，然后重新打开。", comment: ""))
        }
    }

    @ViewBuilder private var statusText: some View {
        switch status {
        case .idle: Text(NSLocalizedString("尚未检查更新", comment: "")).foregroundStyle(.secondary)
        case .checking: HStack(spacing: 8) { ProgressView().controlSize(.small); Text(NSLocalizedString("检查中…", comment: "")) }
        case .upToDate: Text(NSLocalizedString("已是最新版本", comment: "")).foregroundStyle(.secondary)
        case .available(let release):
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: NSLocalizedString("发现新版本 %@", comment: ""), release.version))
                Link(NSLocalizedString("查看发布说明", comment: ""), destination: release.pageURL).font(.caption)
            }
        case .installing(let step): HStack(spacing: 8) { ProgressView().controlSize(.small); Text(step) }
        case .failed(let message): Text(message).foregroundStyle(ThemeColor.kTextNegative).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var actionButton: some View {
        switch status {
        case .available:
            Button(NSLocalizedString("安装更新", comment: "")) { confirmingInstall = true }.buttonStyle(.borderedProminent)
        case .checking, .installing:
            Button(NSLocalizedString("检查更新", comment: "")) {}.disabled(true)
        default:
            Button(NSLocalizedString("检查更新", comment: "")) { Task { await check() } }
        }
    }

    private func check() async {
        status = .checking
        do { status = try await ToolService.checkForAppUpdate().map(Status.available) ?? .upToDate }
        catch { status = .failed(error.localizedDescription) }
    }

    private func install(_ release: AppRelease) async {
        status = .installing(NSLocalizedString("正在准备…", comment: ""))
        do {
            try await ToolService.prepareAppUpdate(release) { step in
                await MainActor.run { status = .installing(step) }
            }
            NSApp.terminate(nil)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
