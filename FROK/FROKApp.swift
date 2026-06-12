import SwiftUI

@main
struct FROKApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var launchAtLoginManager = LaunchAtLoginManager.shared
    @ObservedObject private var accessibilityPermissionManager = AccessibilityPermissionManager.shared

    var body: some Scene {
        MenuBarExtra("FROK", systemImage: "speaker.wave.2.fill") {
            SettingsView()
                .environment(appDelegate.soundLibrary)
                .environmentObject(launchAtLoginManager)
                .environmentObject(accessibilityPermissionManager)
        }
        .menuBarExtraStyle(.window)
    }
}
