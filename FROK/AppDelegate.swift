import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let soundLibrary = SoundLibrary()
    private lazy var commandHandler = SoundCommandHandler(soundLibrary: soundLibrary)
    private var socketServer: SocketServer?
    private var hotkeyManager: GlobalHotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            LaunchAtLoginManager.shared.configureDefaultIfNeeded()
        }

        hotkeyManager = GlobalHotkeyManager(soundLibrary: soundLibrary)
        soundLibrary.onHotkeysChanged = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.hotkeyManager?.sync(with: self.soundLibrary.entries)
            }
        }
        soundLibrary.onHotkeyRecordingChanged = { [weak self] isRecording in
            self?.hotkeyManager?.setRecordingPaused(isRecording)
        }
        hotkeyManager?.sync(with: soundLibrary.entries)

        socketServer = SocketServer(commandHandler: commandHandler)

        do {
            try socketServer?.start()
        } catch {
            Logger.frok.error("Failed to start socket server: \(error.localizedDescription, privacy: .public)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
        socketServer?.stop()
    }
}
