import Foundation

struct SoundEntry: Identifiable, Equatable {
    let id: UUID
    var alias: String
    var bookmarkData: Data
    var volume: Double
    var hotkey: SoundHotkey?
    var playbackMode: SoundPlaybackMode
    var loadStatus: SoundLoadStatus
    var playbackState: SoundPlaybackState

    init(
        id: UUID = UUID(),
        alias: String,
        bookmarkData: Data,
        volume: Double = 1.0,
        hotkey: SoundHotkey? = nil,
        playbackMode: SoundPlaybackMode = .oneShot,
        loadStatus: SoundLoadStatus = .loading,
        playbackState: SoundPlaybackState = .idle
    ) {
        self.id = id
        self.alias = alias
        self.bookmarkData = bookmarkData
        self.volume = volume
        self.hotkey = hotkey
        self.playbackMode = playbackMode
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
    var playbackMode: SoundPlaybackMode

    init(
        id: UUID,
        alias: String,
        bookmarkData: Data,
        volume: Double,
        hotkey: SoundHotkey?,
        playbackMode: SoundPlaybackMode = .oneShot
    ) {
        self.id = id
        self.alias = alias
        self.bookmarkData = bookmarkData
        self.volume = volume
        self.hotkey = hotkey
        self.playbackMode = playbackMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        alias = try container.decode(String.self, forKey: .alias)
        bookmarkData = try container.decode(Data.self, forKey: .bookmarkData)
        volume = try container.decode(Double.self, forKey: .volume)
        hotkey = try container.decodeIfPresent(SoundHotkey.self, forKey: .hotkey)
        playbackMode = try container.decodeIfPresent(SoundPlaybackMode.self, forKey: .playbackMode) ?? .hold
    }
}

extension SoundEntry {
    var stored: StoredSoundEntry {
        StoredSoundEntry(
            id: id,
            alias: alias,
            bookmarkData: bookmarkData,
            volume: volume,
            hotkey: hotkey,
            playbackMode: playbackMode
        )
    }

    init(stored: StoredSoundEntry) {
        self.init(
            id: stored.id,
            alias: stored.alias,
            bookmarkData: stored.bookmarkData,
            volume: stored.volume,
            hotkey: stored.hotkey,
            playbackMode: stored.playbackMode,
            loadStatus: .loading,
            playbackState: .idle
        )
    }
}
