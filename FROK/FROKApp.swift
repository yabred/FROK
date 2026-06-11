import SwiftUI

@main
struct FROKApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("FROK", systemImage: "speaker.wave.2.fill") {
            SettingsView()
        }
        .menuBarExtraStyle(.window)
    }
}
