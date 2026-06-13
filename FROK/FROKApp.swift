import MenuBarExtraAccess
import SwiftUI

@main
struct FROKApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var launchAtLoginManager = LaunchAtLoginManager.shared
    @ObservedObject private var accessibilityPermissionManager = AccessibilityPermissionManager.shared
    @State private var menuBarState = MenuBarState()

    var body: some Scene {
        MenuBarExtra {
            SettingsView()
                .environment(appDelegate.soundLibrary)
                .environment(menuBarState)
                .environmentObject(launchAtLoginManager)
                .environmentObject(accessibilityPermissionManager)
        } label: {
            Image("status_icon")
                .renderingMode(.template)
        }
        .menuBarExtraAccess(isPresented: Binding(
            get: { menuBarState.isPresented },
            set: { menuBarState.isPresented = $0 }
        ))
        .menuBarExtraStyle(.window)
    }
}
