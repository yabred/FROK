import Foundation

enum SoundLoadStatus: Equatable {
    case loading
    case loaded
    case failed(String)
}
