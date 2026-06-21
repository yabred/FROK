import Foundation

enum SoundPlaybackMode: String, Codable, CaseIterable, Equatable {
    case oneShot
    case hold
    case restart

    var label: String {
        switch self {
        case .oneShot:
            "S"
        case .hold:
            "H"
        case .restart:
            "R"
        }
    }

    var tooltip: String {
        switch self {
        case .oneShot:
            "One-shot — plays the full clip; triggers can overlap"
        case .hold:
            "Hold — plays while the key is held, stops on release"
        case .restart:
            "Restart — stops previous playbacks and starts from the beginning"
        }
    }
}
