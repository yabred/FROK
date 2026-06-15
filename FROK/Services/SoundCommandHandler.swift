import Foundation
import OSLog

@Observable
final class SoundCommandHandler {
    private let soundLibrary: SoundLibrary
    private let eventLog: EventLogStore

    init(soundLibrary: SoundLibrary, eventLog: EventLogStore) {
        self.soundLibrary = soundLibrary
        self.eventLog = eventLog
    }

    func handle(_ command: SoundCommand, rawLine: String) {
        Logger.frok.notice("Received: \(command.description, privacy: .public)")

        Task { @MainActor in
            let soundAlias = soundLibrary.aliasThatWouldPlay(for: command)

            switch command {
            case .playDefault:
                soundLibrary.playDefault()
                eventLog.logSocket(message: rawLine, soundAlias: soundAlias)
            case .stopAll:
                soundLibrary.stopAll()
                eventLog.logSocket(message: rawLine, soundAlias: nil, isStop: true)
            case .play(let name):
                soundLibrary.play(alias: name)
                eventLog.logSocket(message: rawLine, soundAlias: soundAlias)
            }
        }
    }
}
