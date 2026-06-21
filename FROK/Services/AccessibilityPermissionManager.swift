import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum AccessibilityAccessState: Equatable {
    case granted
    case notGranted
    case stale
}

@MainActor
final class AccessibilityPermissionManager: ObservableObject {
    static let shared = AccessibilityPermissionManager()

    @Published private(set) var accessState: AccessibilityAccessState

    var isTrusted: Bool {
        accessState == .granted
    }

    var onTrustChanged: ((Bool) -> Void)?

    private var pollTimer: Timer?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var workspaceActivationObserver: NSObjectProtocol?

    private init() {
        accessState = Self.evaluateAccessState()
    }

    func refreshStatus() {
        let newState = Self.evaluateAccessState()
        guard newState != accessState else { return }

        let wasFunctional = accessState == .granted
        accessState = newState
        let isFunctional = newState == .granted
        if wasFunctional != isFunctional {
            onTrustChanged?(isFunctional)
        }
    }

    func startMonitoring() {
        guard pollTimer == nil else { return }

        refreshStatus()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatus()
            }
        }

        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatus()
            }
        }
    }

    func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trustedAfterPrompt = AXIsProcessTrustedWithOptions(options)

        if trustedAfterPrompt, Self.canCreateEventTap() {
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

    func restartApp() {
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }

    var bundlePathForDisplay: String {
        Bundle.main.bundlePath
    }

    var bundleIdentifierForDisplay: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    static func canCreateEventTap() -> Bool {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else {
            return false
        }

        CFMachPortInvalidate(tap)
        return true
    }

    private static func evaluateAccessState() -> AccessibilityAccessState {
        guard AXIsProcessTrusted() else {
            return .notGranted
        }

        return canCreateEventTap() ? .granted : .stale
    }
}
