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
            MenuBarIconLabel(playingIcon: menuBarState.playingIcon)
                .equatable()
        }
        .menuBarExtraAccess(
            isPresented: Binding(
                get: { menuBarState.isPresented },
                set: { menuBarState.isPresented = $0 }
            ),
            statusItem: { _ in
                wireMenuBarIconUpdates()
            }
        )
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)
    }

    private func wireMenuBarIconUpdates() {
        let library = appDelegate.soundLibrary
        let accentColorManager = appDelegate.accentColorManager

        let sync = {
            menuBarState.updatePlayingIcon(
                isPlaying: library.isPlayingAny,
                accentIndex: accentColorManager.currentIndex,
                color: accentColorManager.nsColor
            )
        }

        library.onPlaybackActivityChanged = sync
        accentColorManager.onColorChanged = sync
        sync()
    }
}

private struct MenuBarIconLabel: View, Equatable {
    let playingIcon: NSImage?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.playingIcon === rhs.playingIcon
    }

    var body: some View {
        if let playingIcon {
            Image(nsImage: playingIcon)
        } else {
            Image("status_icon")
                .renderingMode(.template)
        }
    }
}
