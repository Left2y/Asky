import ServiceManagement

extension ToolService {
    @MainActor
    public static var launchAtLoginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @MainActor
    public static func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
    }

    /// Preserve pending system approval and any already enabled registration.
    @MainActor
    public static func enableDefaultLaunchAtLogin() throws {
        if SMAppService.mainApp.status == .notRegistered {
            try setLaunchAtLogin(true)
        }
    }
}
