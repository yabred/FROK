import Foundation
import OSLog

enum SocketError: LocalizedError {
    case createFailed
    case bindFailed(Int32)
    case listenFailed(Int32)
    case pathTooLong

    var errorDescription: String? {
        switch self {
        case .createFailed:
            "Failed to create Unix socket"
        case .bindFailed(let code):
            "Failed to bind Unix socket (errno \(code))"
        case .listenFailed(let code):
            "Failed to listen on Unix socket (errno \(code))"
        case .pathTooLong:
            "Socket path is too long"
        }
    }
}

final class SocketServer {
    private let socketPath: String
    private let commandHandler: SoundCommandHandler
    private var serverSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.user.frok.socket", qos: .userInitiated)

    init(socketPath: String = "/tmp/frok.sock", commandHandler: SoundCommandHandler) {
        self.socketPath = socketPath
        self.commandHandler = commandHandler
    }

    func start() throws {
        unlinkExistingSocket()

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw SocketError.createFailed
        }

        try bindUnixSocket(path: socketPath, to: fd)

        guard listen(fd, SOMAXCONN) == 0 else {
            close(fd)
            throw SocketError.listenFailed(errno)
        }

        chmod(socketPath, 0o666)

        var flags = fcntl(fd, F_GETFL, 0)
        flags |= O_NONBLOCK
        _ = fcntl(fd, F_SETFL, flags)

        serverSocket = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnections()
        }
        source.resume()
        acceptSource = source

        Logger.frok.notice("Socket server ready at \(self.socketPath, privacy: .public)")
    }

    func stop() {
        acceptSource?.cancel()
        acceptSource = nil

        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }

        unlinkExistingSocket()
    }

    private func unlinkExistingSocket() {
        if FileManager.default.fileExists(atPath: socketPath) {
            unlink(socketPath)
        }
    }

    private func bindUnixSocket(path: String, to fd: Int32) throws {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathLength = path.utf8.count
        guard pathLength < MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            throw SocketError.pathTooLong
        }

        _ = path.withCString { cString in
            strncpy(&addr.sun_path.0, cString, pathLength)
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            close(fd)
            throw SocketError.bindFailed(errno)
        }
    }

    private func acceptConnections() {
        while true {
            let clientFd = accept(serverSocket, nil, nil)
            if clientFd < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    break
                }
                Logger.frok.error("Accept failed (errno \(errno))")
                break
            }

            handleClient(fd: clientFd)
        }
    }

    private func handleClient(fd: Int32) {
        defer { close(fd) }

        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)

        while true {
            let bytesRead = read(fd, &chunk, chunk.count)
            if bytesRead <= 0 {
                break
            }
            buffer.append(contentsOf: chunk[0..<bytesRead])
        }

        let line = String(data: buffer, encoding: .utf8) ?? ""
        let soundCommand = SoundCommand(rawLine: line)
        commandHandler.handle(soundCommand, rawLine: line.trimmingCharacters(in: .newlines))
    }
}
