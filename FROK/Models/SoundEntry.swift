import Foundation

struct SoundEntry: Identifiable, Equatable {
    let id: UUID
    var alias: String
    var bookmarkData: Data
    var volume: Double
    var loadStatus: SoundLoadStatus
    var playbackState: SoundPlaybackState

    init(
        id: UUID = UUID(),
        alias: String,
        bookmarkData: Data,
        volume: Double = 1.0,
        loadStatus: SoundLoadStatus = .loading,
        playbackState: SoundPlaybackState = .idle
    ) {
        self.id = id
        self.alias = alias
        self.bookmarkData = bookmarkData
        self.volume = volume
        self.loadStatus = loadStatus
        self.playbackState = playbackState
    }
}

struct StoredSoundEntry: Codable, Equatable {
    let id: UUID
    var alias: String
    var bookmarkData: Data
    var volume: Double
}

extension SoundEntry {
    var stored: StoredSoundEntry {
        StoredSoundEntry(id: id, alias: alias, bookmarkData: bookmarkData, volume: volume)
    }

    init(stored: StoredSoundEntry) {
        self.init(
            id: stored.id,
            alias: stored.alias,
            bookmarkData: stored.bookmarkData,
            volume: stored.volume,
            loadStatus: .loading,
            playbackState: .idle
        )
    }
}

enum SoundPathFormatting {
    static func truncatedPath(_ url: URL, maxLength: Int = 30) -> String {
        let path = url.path
        guard path.count > maxLength else { return path }
        return "..." + path.suffix(maxLength)
    }
}
