import Foundation

enum SocketClientError: LocalizedError {
    case createFailed
    case pathTooLong
    case connectFailed(Int32)
    case writeFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .createFailed:
            "Failed to create Unix socket"
        case .pathTooLong:
            "Socket path is too long"
        case .connectFailed(let code):
            if code == ENOENT {
                "FROK is not running (socket not found at \(FROKSocketPath.default))"
            } else if code == ECONNREFUSED {
                "Connection refused — is FROK running?"
            } else {
                "Failed to connect to FROK (errno \(code))"
            }
        case .writeFailed(let code):
            "Failed to send command (errno \(code))"
        }
    }
}

enum SocketClient {
    static func send(_ message: String, socketPath: String) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw SocketClientError.createFailed
        }
        defer { close(fd) }

        try connectUnixSocket(path: socketPath, to: fd)

        let payload = Array((message + "\n").utf8)
        var bytesWritten = 0
        while bytesWritten < payload.count {
            let writeResult = payload.withUnsafeBytes { buffer in
                write(
                    fd,
                    buffer.baseAddress!.advanced(by: bytesWritten),
                    payload.count - bytesWritten
                )
            }
            if writeResult < 0 {
                throw SocketClientError.writeFailed(errno)
            }
            bytesWritten += writeResult
        }

        _ = shutdown(fd, SHUT_WR)
    }

    private static func connectUnixSocket(path: String, to fd: Int32) throws {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathLength = path.utf8.count
        guard pathLength < MemoryLayout.size(ofValue: addr.sun_path) else {
            throw SocketClientError.pathTooLong
        }

        _ = path.withCString { cString in
            strncpy(&addr.sun_path.0, cString, pathLength)
        }

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else {
            throw SocketClientError.connectFailed(errno)
        }
    }
}
