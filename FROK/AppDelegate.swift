import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let soundLibrary = SoundLibrary()
    private lazy var commandHandler = SoundCommandHandler(soundLibrary: soundLibrary)
    private var socketServer: SocketServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            LaunchAtLoginManager.shared.configureDefaultIfNeeded()
        }

        socketServer = SocketServer(commandHandler: commandHandler)

        do {
            try socketServer?.start()
        } catch {
            Logger.frok.error("Failed to start socket server: \(error.localizedDescription, privacy: .public)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        socketServer?.stop()
    }
}
