import OSLog
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool

    private let hasConfiguredKey = "hasConfiguredLaunchAtLogin"
    private let isPreviewMode: Bool

    private init() {
        isPreviewMode = false
        isEnabled = Self.isRegistered
    }

    init(previewIsEnabled: Bool) {
        isPreviewMode = true
        isEnabled = previewIsEnabled
    }

    func refreshStatus() {
        guard !isPreviewMode else { return }
        isEnabled = Self.isRegistered
    }

    func configureDefaultIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: hasConfiguredKey) else { return }

        UserDefaults.standard.set(true, forKey: hasConfiguredKey)
        setEnabled(true)
    }

    func setEnabled(_ enabled: Bool) {
        if isPreviewMode {
            isEnabled = enabled
            return
        }

        do {
            if enabled {
                guard SMAppService.mainApp.status != .enabled else { return }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status == .enabled else { return }
                try SMAppService.mainApp.unregister()
            }
            refreshStatus()
        } catch {
            Logger.frok.error(
                "Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription, privacy: .public)"
            )
            refreshStatus()
        }
    }

    private static var isRegistered: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
