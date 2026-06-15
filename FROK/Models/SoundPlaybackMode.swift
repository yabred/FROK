import Foundation

enum SoundPlaybackMode: String, Codable, CaseIterable, Equatable {
    case oneShot
    case hold

    var label: String {
        switch self {
        case .oneShot:
            "S"
        case .hold:
            "H"
        }
    }
}
