import Foundation

enum SoundPersistence {
    private static let storageKey = "storedSounds"

    static func load() -> [StoredSoundEntry] {
        let stored: [StoredSoundEntry]
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            stored = (try? JSONDecoder().decode([StoredSoundEntry].self, from: data)) ?? []
        } else {
            stored = []
        }

        let seeded = BundledSounds.makeStoredEntries(existing: stored)
        if seeded.count != stored.count {
            save(seeded)
        }
        return seeded
    }

    static func save(_ entries: [StoredSoundEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

enum SoundBookmark {
    enum Error: Swift.Error, LocalizedError {
        case createFailed
        case resolveFailed

        var errorDescription: String? {
            switch self {
            case .createFailed:
                "Failed to create security-scoped bookmark"
            case .resolveFailed:
                "Failed to resolve bookmark"
            }
        }
    }

    static func create(from url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw Error.createFailed
        }
    }

    static func resolve(_ bookmarkData: Data) throws -> URL {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                throw Error.resolveFailed
            }
            return url
        } catch {
            throw Error.resolveFailed
        }
    }
}
