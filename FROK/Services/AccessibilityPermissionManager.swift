import AppKit
import ApplicationServices
import Foundation

@MainActor
final class AccessibilityPermissionManager: ObservableObject {
    static let shared = AccessibilityPermissionManager()

    @Published private(set) var isTrusted: Bool

    var onTrustChanged: ((Bool) -> Void)?

    private var pollTimer: Timer?
    private var didBecomeActiveObserver: NSObjectProtocol?

    private init() {
        isTrusted = AXIsProcessTrusted()
    }

    func refreshStatus() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }

        isTrusted = trusted
        onTrustChanged?(trusted)
    }

    func startMonitoring() {
        guard pollTimer == nil else { return }

        refreshStatus()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
    }

    func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trustedAfterPrompt = AXIsProcessTrustedWithOptions(options)

        if trustedAfterPrompt {
            refreshStatus()
            return
        }

        let modernURL = URL(
            string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Security_Accessibility"
        )
        let legacyURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )

        if let modernURL, NSWorkspace.shared.open(modernURL) {
            return
        }

        if let legacyURL {
            NSWorkspace.shared.open(legacyURL)
        }
    }

    var bundlePathForDisplay: String {
        Bundle.main.bundlePath
    }
}
