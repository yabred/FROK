import Foundation
import OSLog

@Observable
final class SoundCommandHandler {
    private let soundLibrary: SoundLibrary

    init(soundLibrary: SoundLibrary) {
        self.soundLibrary = soundLibrary
    }

    func handle(_ command: SoundCommand) {
        Logger.frok.notice("Received: \(command.description, privacy: .public)")

        Task { @MainActor in
            switch command {
            case .playDefault:
                soundLibrary.playDefault()
            case .stopAll:
                soundLibrary.stopAll()
            case .play(let name):
                soundLibrary.play(alias: name)
            }
        }
    }
}
