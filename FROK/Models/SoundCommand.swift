import Foundation

enum SoundCommand: Equatable, CustomStringConvertible {
    case ignore
    case playDefault
    case stopAll
    case play(name: String)

    init(rawLine: String) {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            self = .ignore
        } else if trimmed == "play" {
            self = .playDefault
        } else if trimmed == "-stop" {
            self = .stopAll
        } else {
            self = .play(name: trimmed)
        }
    }

    var description: String {
        switch self {
        case .ignore:
            "ignore"
        case .playDefault:
            "playDefault"
        case .stopAll:
            "stopAll"
        case .play(let name):
            "play(name: \"\(name)\")"
        }
    }
}
