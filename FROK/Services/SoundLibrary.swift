import AppKit
import AVFoundation
import Foundation
import OSLog
import SwiftUI

@MainActor
@Observable
final class SoundLibrary {
    private(set) var entries: [SoundEntry] = []

    var onHotkeysChanged: (() -> Void)?
    var onHotkeyRecordingChanged: ((Bool) -> Void)?

    private var buffers: [UUID: AVAudioPCMBuffer] = [:]
    private var resolvedURLs: [UUID: URL] = [:]
    private var securityScopedURLs: [UUID: URL] = [:]

    private let engine = AVAudioEngine()

    private struct ActivePlayback: Identifiable {
        let id = UUID()
        let entryID: UUID
        let playerNode: AVAudioPlayerNode
        let mixerNode: AVAudioMixerNode
    }

    private var activePlaybacks: [ActivePlayback] = []
    private var stopFlashTasks: [UUID: Task<Void, Never>] = [:]
    private let persistenceEnabled: Bool

    init() {
        persistenceEnabled = true
        let stored = SoundPersistence.load()
        entries = stored.map(SoundEntry.init(stored:))
        for entry in entries {
            Task { await preload(entryID: entry.id) }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSystemWake()
            }
        }
    }

    init(previewEntries: [SoundEntry]) {
        persistenceEnabled = false
        entries = previewEntries
    }

    func addSounds(from urls: [URL]) {
        var existingPaths = Set(resolvedURLs.values.map(\.path))

        for url in urls {
            let resolved = url.resolvingSymlinksInPath()

            guard !existingPaths.contains(resolved.path) else { continue }

            do {
                let bookmarkData = try SoundBookmark.create(from: url)
                let alias = uniqueAlias(for: resolved.deletingPathExtension().lastPathComponent)
                let playbackMode = Self.defaultPlaybackMode(for: resolved)
                let entry = SoundEntry(alias: alias, bookmarkData: bookmarkData, playbackMode: playbackMode)
                entries.append(entry)
                existingPaths.insert(resolved.path)
                persist()
                Task { await preload(entryID: entry.id) }
            } catch {
                Logger.frok.error("Failed to add sound: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func remove(id: UUID) {
        stopPlaybacks(for: id, manualFromUI: false)
        stopFlashTasks[id]?.cancel()
        stopFlashTasks[id] = nil

        if let url = securityScopedURLs[id] {
            url.stopAccessingSecurityScopedResource()
            securityScopedURLs[id] = nil
        }

        buffers[id] = nil
        resolvedURLs[id] = nil
        entries.removeAll { $0.id == id }
        persist()
        onHotkeysChanged?()
    }

    func updateAlias(id: UUID, alias: String) {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        guard !entries.contains(where: { $0.id != id && $0.alias == trimmed }) else { return }

        entries[index].alias = trimmed
        persist()
    }

    func updateVolume(id: UUID, volume: Double) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let clamped = min(max(volume, 0), 1.5)
        entries[index].volume = clamped
        persist()

        for playback in activePlaybacks where playback.entryID == id {
            applyPlaybackVolume(clamped, to: playback.mixerNode)
        }
    }

    @discardableResult
    func updateHotkey(id: UUID, hotkey: SoundHotkey?) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }

        if let hotkey {
            guard hotkey.isValid else { return false }
            guard !entries.contains(where: { $0.id != id && $0.hotkey == hotkey }) else { return false }
        }

        entries[index].hotkey = hotkey
        persist()
        onHotkeysChanged?()
        return true
    }

    func keyDownPlay(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }

        switch entry.playbackMode {
        case .oneShot:
            playEntry(id: id)
        case .hold:
            stopPlaybacks(for: id, manualFromUI: false)
            playEntry(id: id)
        }
    }

    func keyUpStop(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        guard entry.playbackMode == .hold else { return }
        stopPlaybacks(for: id, manualFromUI: false)
    }

    func updatePlaybackMode(id: UUID, mode: SoundPlaybackMode) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].playbackMode = mode
        persist()
    }

    func isHotkeyAvailable(_ hotkey: SoundHotkey, excluding id: UUID) -> Bool {
        !entries.contains { $0.id != id && $0.hotkey == hotkey }
    }

    func togglePlayback(id: UUID) {
        if isPlaying(entryID: id) {
            stopPlaybacks(for: id, manualFromUI: true)
        } else {
            playEntry(id: id)
        }
    }

    func ensureBundledFrogAtFirstPosition() {
        guard !entries.contains(where: { $0.id == BundledSounds.frogID }) else { return }
        let entry = SoundEntry(stored: BundledSounds.frogStoredEntry())
        entries.insert(entry, at: 0)
        persist()
        Task { await preload(entryID: entry.id) }
    }

    func play(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        switch entry.loadStatus {
        case .loaded:
            playEntry(id: id)
        case .loading:
            Task { await playWhenLoaded(entryID: id) }
        case .failed:
            break
        }
    }

    func play(alias: String) {
        switch resolveAliasMatch(alias) {
        case .loaded(let entryID):
            playEntry(id: entryID)
        case .loading(let entryID):
            Task { await playWhenLoaded(entryID: entryID) }
        case .none:
            Logger.frok.error("Sound not found for alias \"\(alias, privacy: .public)\"")
        }
    }

    func playDefault() {
        if let entry = entries.first(where: { $0.loadStatus == .loaded }) {
            playEntry(id: entry.id)
        } else {
            Logger.frok.error("No loaded sounds available for default play")
        }
    }

    func aliasThatWouldPlay(for command: SoundCommand) -> String? {
        switch command {
        case .ignore, .stopAll:
            return nil
        case .playDefault:
            return entries.first(where: { $0.loadStatus == .loaded })?.alias
        case .play(let name):
            return entry(matchingAlias: name)?.alias
        }
    }

    func stopAll() {
        let entryIDs = Set(activePlaybacks.map(\.entryID))
        for entryID in entryIDs {
            stopPlaybacks(for: entryID, manualFromUI: false)
        }
    }

    func resolvedURL(for id: UUID) -> URL? {
        resolvedURLs[id]
    }

    var loadedMemoryUsage: Int {
        buffers.values.reduce(0) { $0 + Self.memorySize(of: $1) }
    }

    var formattedLoadedMemoryUsage: String {
        Self.byteCountFormatter.string(fromByteCount: Int64(loadedMemoryUsage))
    }

    func aliasBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { [self] in
                entries.first(where: { $0.id == id })?.alias ?? ""
            },
            set: { [self] newValue in
                updateAlias(id: id, alias: newValue)
            }
        )
    }

    func volumeBinding(for id: UUID) -> Binding<Double> {
        Binding(
            get: { [self] in
                entries.first(where: { $0.id == id })?.volume ?? 1.0
            },
            set: { [self] newValue in
                updateVolume(id: id, volume: newValue)
            }
        )
    }

    func hotkeyBinding(for id: UUID) -> Binding<SoundHotkey?> {
        Binding(
            get: { [self] in
                entries.first(where: { $0.id == id })?.hotkey
            },
            set: { [self] newValue in
                updateHotkey(id: id, hotkey: newValue)
            }
        )
    }

    func playbackModeBinding(for id: UUID) -> Binding<SoundPlaybackMode> {
        Binding(
            get: { [self] in
                entries.first(where: { $0.id == id })?.playbackMode ?? .oneShot
            },
            set: { [self] newValue in
                updatePlaybackMode(id: id, mode: newValue)
            }
        )
    }

    // MARK: - Preload

    private func preload(entryID: UUID) async {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }

        entries[index].loadStatus = .loading

        do {
            let url = try resolveAndAccessURL(for: entryID)
            let buffer = try await Task.detached(priority: .userInitiated) {
                try Self.loadPCMBuffer(from: url)
            }.value

            guard let currentIndex = entries.firstIndex(where: { $0.id == entryID }) else { return }
            buffers[entryID] = buffer
            entries[currentIndex].loadStatus = .loaded
        } catch {
            guard let currentIndex = entries.firstIndex(where: { $0.id == entryID }) else { return }
            entries[currentIndex].loadStatus = .failed(error.localizedDescription)
            Logger.frok.error("Failed to preload sound: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated private static func loadPCMBuffer(from url: URL) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw SoundBookmark.Error.resolveFailed
        }
        try file.read(into: buffer)
        return buffer
    }

    private func resolveAndAccessURL(for entryID: UUID) throws -> URL {
        if let cached = resolvedURLs[entryID] {
            return cached
        }

        guard let entry = entries.first(where: { $0.id == entryID }) else {
            throw SoundBookmark.Error.resolveFailed
        }

        if let resourceName = entry.bundledResourceName {
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mp3") else {
                throw SoundBookmark.Error.resolveFailed
            }
            resolvedURLs[entryID] = url
            return url
        }

        let url = try SoundBookmark.resolve(entry.bookmarkData)
        guard url.startAccessingSecurityScopedResource() else {
            throw SoundBookmark.Error.resolveFailed
        }

        securityScopedURLs[entryID] = url
        resolvedURLs[entryID] = url.resolvingSymlinksInPath()
        return url
    }

    // MARK: - Playback

    private func playEntry(id: UUID) {
        guard let buffer = buffers[id],
              let index = entries.firstIndex(where: { $0.id == id }),
              entries[index].loadStatus == .loaded else { return }

        let volume = entries[index].volume

        do {
            try startPlayback(entryID: id, buffer: buffer, volume: volume)
        } catch {
            Logger.frok.error("Failed to play sound: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func applyPlaybackVolume(_ volume: Double, to mixerNode: AVAudioMixerNode) {
        mixerNode.outputVolume = Float(min(max(volume, 0), 1.5))
    }

    private func ensureEngineRunning() throws {
        guard !engine.isRunning else { return }
        try engine.start()
    }

    private func handleSystemWake() {
        guard !activePlaybacks.isEmpty || engine.isRunning else { return }

        let staleCount = activePlaybacks.count
        Logger.frok.notice("System wake: resetting audio engine and \(staleCount) stale playback(s)")

        let entryIDs = Set(activePlaybacks.map(\.entryID))
        let playbacks = activePlaybacks
        for playback in playbacks {
            teardownPlayback(playback)
        }

        if engine.isRunning {
            engine.stop()
        }

        for entryID in entryIDs {
            stopFlashTasks[entryID]?.cancel()
            stopFlashTasks[entryID] = nil
            refreshPlaybackState(for: entryID)
        }
    }

    private func startPlayback(entryID: UUID, buffer: AVAudioPCMBuffer, volume: Double) throws {
        let playerNode = AVAudioPlayerNode()
        let mixerNode = AVAudioMixerNode()

        engine.attach(playerNode)
        engine.attach(mixerNode)

        let format = buffer.format
        engine.connect(playerNode, to: mixerNode, format: format)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: format)

        try ensureEngineRunning()

        applyPlaybackVolume(volume, to: mixerNode)

        let playback = ActivePlayback(entryID: entryID, playerNode: playerNode, mixerNode: mixerNode)
        activePlaybacks.append(playback)
        refreshPlaybackState(for: entryID)

        playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            Task { @MainActor in
                self?.playbackFinished(playbackID: playback.id)
            }
        }

        playerNode.play()
    }

    private func playbackFinished(playbackID: UUID) {
        guard let playback = activePlaybacks.first(where: { $0.id == playbackID }) else { return }
        teardownPlayback(playback)
        refreshPlaybackState(for: playback.entryID)
    }

    private func stopPlaybacks(for entryID: UUID, manualFromUI: Bool) {
        let playbacks = activePlaybacks.filter { $0.entryID == entryID }
        for playback in playbacks {
            teardownPlayback(playback)
        }

        if manualFromUI {
            showStopFlash(for: entryID)
        } else {
            refreshPlaybackState(for: entryID)
        }
    }

    private func teardownPlayback(_ playback: ActivePlayback) {
        playback.playerNode.stop()
        engine.disconnectNodeOutput(playback.playerNode)
        engine.disconnectNodeOutput(playback.mixerNode)
        engine.detach(playback.playerNode)
        engine.detach(playback.mixerNode)
        activePlaybacks.removeAll { $0.id == playback.id }
    }

    private func isPlaying(entryID: UUID) -> Bool {
        activePlaybacks.contains { $0.entryID == entryID }
    }

    private func refreshPlaybackState(for entryID: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].playbackState = isPlaying(entryID: entryID) ? .playing : .idle
    }

    private func showStopFlash(for entryID: UUID) {
        stopFlashTasks[entryID]?.cancel()

        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].playbackState = .stoppedFlash

        stopFlashTasks[entryID] = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            guard let currentIndex = entries.firstIndex(where: { $0.id == entryID }) else { return }
            if !isPlaying(entryID: entryID) {
                entries[currentIndex].playbackState = .idle
            }
            stopFlashTasks[entryID] = nil
        }
    }

    // MARK: - Helpers

    private enum AliasMatch {
        case loaded(UUID)
        case loading(UUID)
    }

    private func entry(matchingAlias alias: String) -> SoundEntry? {
        if let entry = entries.first(where: { $0.alias == alias }) {
            return entry
        }
        return entries.first(where: { $0.alias.caseInsensitiveCompare(alias) == .orderedSame })
    }

    private func resolveAliasMatch(_ alias: String) -> AliasMatch? {
        guard let entry = entry(matchingAlias: alias) else { return nil }

        switch entry.loadStatus {
        case .loaded:
            return .loaded(entry.id)
        case .loading:
            return .loading(entry.id)
        case .failed:
            return nil
        }
    }

    private func playWhenLoaded(entryID: UUID) async {
        for _ in 0..<50 {
            guard !Task.isCancelled else { return }
            guard let entry = entries.first(where: { $0.id == entryID }) else { return }

            switch entry.loadStatus {
            case .loaded:
                playEntry(id: entryID)
                return
            case .failed:
                return
            case .loading:
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private static let oneShotMaxDuration: TimeInterval = 3

    nonisolated private static func defaultPlaybackMode(for url: URL) -> SoundPlaybackMode {
        guard let duration = audioDuration(of: url) else { return .hold }
        return duration <= oneShotMaxDuration ? .oneShot : .hold
    }

    nonisolated private static func audioDuration(of url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    private static func memorySize(of buffer: AVAudioPCMBuffer) -> Int {
        let frameLength = Int(buffer.frameLength)
        let bytesPerFrame = Int(buffer.format.streamDescription.pointee.mBytesPerFrame)
        if buffer.format.isInterleaved {
            return frameLength * bytesPerFrame
        }
        return frameLength * bytesPerFrame * Int(buffer.format.channelCount)
    }

    private func uniqueAlias(for base: String) -> String {
        var candidate = base
        var suffix = 2
        while entries.contains(where: { $0.alias == candidate }) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func persist() {
        guard persistenceEnabled else { return }
        SoundPersistence.save(entries.map(\.stored))
    }
}
