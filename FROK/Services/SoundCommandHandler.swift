import Foundation
import OSLog

@Observable
final class SoundCommandHandler {
    func handle(_ command: SoundCommand) {
        Logger.frok.notice("Received: \(command.description, privacy: .public)")
    }
}
