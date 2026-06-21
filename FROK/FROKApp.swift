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
                .environment(appDelegate.accentColorManager)
                .environment(appDelegate.eventLogStore)
                .environment(menuBarState)
                .environmentObject(launchAtLoginManager)
                .environmentObject(accessibilityPermissionManager)
        } label: {
            menuBarIconLabel
        }
        .menuBarExtraAccess(
            isPresented: Binding(
                get: { menuBarState.isPresented },
                set: { menuBarState.isPresented = $0 }
            ),
            statusItem: { _ in
                let library = appDelegate.soundLibrary
                library.onPlaybackActivityChanged = {
                    menuBarState.isSoundPlaying = library.isPlayingAny
                }
                menuBarState.isSoundPlaying = library.isPlayingAny
            }
        )
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)
    }

    @ViewBuilder
    private var menuBarIconLabel: some View {
        if menuBarState.isSoundPlaying {
            Image(nsImage: StatusBarIcon.playingImage(
                accentIndex: appDelegate.accentColorManager.currentIndex,
                color: appDelegate.accentColorManager.nsColor
            ))
        } else {
            Image(nsImage: StatusBarIcon.templateImage())
        }
    }
}
