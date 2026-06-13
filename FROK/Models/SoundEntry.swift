import Foundation

struct SoundEntry: Identifiable, Equatable {
    let id: UUID
    var alias: String
    var bookmarkData: Data
    var volume: Double
    var hotkey: SoundHotkey?
    var loadStatus: SoundLoadStatus
    var playbackState: SoundPlaybackState

    init(
        id: UUID = UUID(),
        alias: String,
        bookmarkData: Data,
        volume: Double = 1.0,
        hotkey: SoundHotkey? = nil,
        loadStatus: SoundLoadStatus = .loading,
        playbackState: SoundPlaybackState = .idle
    ) {
        self.id = id
        self.alias = alias
        self.bookmarkData = bookmarkData
        self.volume = volume
        self.hotkey = hotkey
        self.loadStatus = loadStatus
        self.playbackState = playbackState
    }
}

struct StoredSoundEntry: Codable, Equatable {
    let id: UUID
    var alias: String
    var bookmarkData: Data
    var volume: Double
    var hotkey: SoundHotkey?
}

extension SoundEntry {
    var stored: StoredSoundEntry {
        StoredSoundEntry(id: id, alias: alias, bookmarkData: bookmarkData, volume: volume, hotkey: hotkey)
    }

    init(stored: StoredSoundEntry) {
        self.init(
            id: stored.id,
            alias: stored.alias,
            bookmarkData: stored.bookmarkData,
            volume: stored.volume,
            hotkey: stored.hotkey,
            loadStatus: .loading,
            playbackState: .idle
        )
    }
}
