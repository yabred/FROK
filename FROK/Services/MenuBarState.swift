import SwiftUI

@MainActor
@Observable
final class MenuBarState {
    var isPresented = false
    var isSoundPlaying = false
    private(set) var isPickingFiles = false

    func beginFilePick() {
        isPickingFiles = true
    }

    /// MenuBarExtra can hide its window without updating `isPresented`.
    /// Sync on the next run loop so the status item is not left pressed while the panel is open.
    func notifyPickerDidOpen() {
        Task { @MainActor in
            isPresented = false
        }
    }

    func endFilePick(reopenSettings: Bool = true) {
        isPickingFiles = false
        guard reopenSettings else { return }
        presentSettings()
    }

    private func presentSettings() {
        isPresented = false
        Task { @MainActor in
            isPresented = true
        }
    }
}
