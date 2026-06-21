import CryptoKit
import Foundation

enum BundledSounds {
    static let frogID = UUID(uuidString: "F1A7A000-0000-4000-8000-000000000001")!

    static func allResourceNames() -> [String] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil) ?? []
        return urls
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    static func id(for resourceName: String) -> UUID {
        if resourceName == "frog" { return frogID }

        let hash = SHA256.hash(data: Data("frok-bundled:\(resourceName)".utf8))
        var bytes = Array(hash.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }

    static func storedEntry(for resourceName: String) -> StoredSoundEntry {
        StoredSoundEntry(
            id: id(for: resourceName),
            alias: resourceName,
            bookmarkData: Data(),
            volume: 1.0,
            hotkey: nil,
            playbackMode: .oneShot,
            bundledResourceName: resourceName
        )
    }

    static func frogStoredEntry() -> StoredSoundEntry {
        storedEntry(for: "frog")
    }

    static func makeStoredEntries(existing: [StoredSoundEntry]) -> [StoredSoundEntry] {
        var result = existing
        guard !result.contains(where: { $0.id == frogID }) else { return result }
        result.append(frogStoredEntry())
        return result
    }
}
