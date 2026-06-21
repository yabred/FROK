import Foundation

let args = Array(CommandLine.arguments.dropFirst())

guard !args.isEmpty else {
    fputs(
        """
        Usage: frok stop
               frok <alias>

        """,
        stderr
    )
    exit(1)
}

let message: String
if args.count == 1, args[0] == "stop" {
    message = "-stop"
} else {
    message = args.joined(separator: " ")
}

guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    fputs("Error: alias must not be empty\n", stderr)
    exit(1)
}

do {
    try SocketClient.send(message, socketPath: FROKSocketPath.default)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
