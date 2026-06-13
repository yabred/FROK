import SwiftUI

@main
struct FROKApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var launchAtLoginManager = LaunchAtLoginManager.shared
    @ObservedObject private var accessibilityPermissionManager = AccessibilityPermissionManager.shared

    var body: some Scene {
        MenuBarExtra {
            SettingsView()
                .environment(appDelegate.soundLibrary)
                .environmentObject(launchAtLoginManager)
                .environmentObject(accessibilityPermissionManager)
        } label: {
            Image("status_icon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}
