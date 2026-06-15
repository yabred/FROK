import Foundation

struct EventLogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let source: Source
    let soundAlias: String?
    let isStop: Bool

    enum Source {
        case hotkey(SoundHotkey)
        case socket(message: String)
        case ui
    }

    var playbackLabel: String {
        if isStop {
            return soundAlias ?? "Stop all"
        }
        if let soundAlias {
            return soundAlias
        }
        return "No sound"
    }
}

@MainActor
@Observable
final class EventLogStore {
    private(set) var entries: [EventLogEntry] = []
    private let maxEntries = 500

    func logHotkey(hotkey: SoundHotkey, soundAlias: String) {
        append(
            EventLogEntry(
                source: .hotkey(hotkey),
                soundAlias: soundAlias,
                isStop: false
            )
        )
    }

    func logSocket(message: String, soundAlias: String?, isStop: Bool = false) {
        append(
            EventLogEntry(
                source: .socket(message: message),
                soundAlias: soundAlias,
                isStop: isStop
            )
        )
    }

    func logUI(soundAlias: String, isStop: Bool = false) {
        append(
            EventLogEntry(
                source: .ui,
                soundAlias: soundAlias,
                isStop: isStop
            )
        )
    }

    func clear() {
        entries.removeAll()
    }

    private func append(_ entry: EventLogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}
