import SwiftUI

@MainActor
@Observable
final class AccentColorManager {
    static let colors: [Color] = [
        Color(red: 0.475, green: 0.912, blue: 0.353),
        Color(red: 1.0, green: 0.231, blue: 0.188),
        Color(red: 1.0, green: 0.584, blue: 0.0),
        Color(red: 1.0, green: 0.8, blue: 0.0),
        Color(red: 1.0, green: 0.176, blue: 0.333),
        Color(red: 0.686, green: 0.322, blue: 0.871),
        Color(red: 0.0, green: 0.478, blue: 1.0),
        Color(red: 0.196, green: 0.678, blue: 0.902),
        Color(red: 0.0, green: 0.78, blue: 0.745),
        Color(red: 0.345, green: 0.337, blue: 0.839),
    ]

    private var index: Int
    private let persistenceEnabled: Bool
    private static let indexKey = "accentColorIndex"

    var color: Color { Self.colors[index] }

    init() {
        persistenceEnabled = true
        let storedIndex = UserDefaults.standard.integer(forKey: Self.indexKey)
        index = storedIndex % Self.colors.count
    }

    init(previewColorIndex: Int) {
        persistenceEnabled = false
        index = previewColorIndex % Self.colors.count
    }

    func cycle() {
        index = (index + 1) % Self.colors.count
        guard persistenceEnabled else { return }
        UserDefaults.standard.set(index, forKey: Self.indexKey)
    }
}
