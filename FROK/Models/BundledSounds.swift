import Foundation

enum BundledSounds {
    static let frogID = UUID(uuidString: "F1A7A000-0000-4000-8000-000000000001")!

    static func makeStoredEntries(existing: [StoredSoundEntry]) -> [StoredSoundEntry] {
        var result = existing
        guard !result.contains(where: { $0.id == frogID }) else { return result }
        result.append(
            StoredSoundEntry(
                id: frogID,
                alias: "frog",
                bookmarkData: Data(),
                volume: 1.0,
                hotkey: nil,
                playbackMode: .oneShot,
                bundledResourceName: "frog"
            )
        )
        return result
    }
}
