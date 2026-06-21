import Foundation

enum FROKSocketPath {
    #if DEBUG
    static let `default` = "/tmp/frok-debug.sock"
    #else
    static let `default` = "/tmp/frok.sock"
    #endif
}
