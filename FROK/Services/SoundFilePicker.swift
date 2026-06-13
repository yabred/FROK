import AppKit
import UniformTypeIdentifiers

@MainActor
enum SoundFilePicker {
    static func pick(onDisplayed: (() -> Void)? = nil, onCompletion: @escaping ([URL]?) -> Void) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mp3, .aiff, .wav]

        panel.begin { response in
            if response == .OK {
                onCompletion(panel.urls)
            } else {
                onCompletion(nil)
            }
        }
        panel.orderFrontRegardless()
        onDisplayed?()
    }
}
