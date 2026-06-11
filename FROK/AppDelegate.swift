import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let commandHandler = SoundCommandHandler()
    private var socketServer: SocketServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
