import ApplicationServices
import CoreGraphics
import Foundation
import OSLog

final class GlobalHotkeyManager: @unchecked Sendable {
    private let soundLibrary: SoundLibrary
    private var hotkeyMap: [SoundHotkey: UUID] = [:]
    private var keyCodeToHotkeys: [UInt16: [SoundHotkey]] = [:]
    private var heldEntryIDs: Set<UUID> = []
    private var isRecordingPaused = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let lock = NSLock()

    init(soundLibrary: SoundLibrary) {
        self.soundLibrary = soundLibrary
    }

    func setRecordingPaused(_ paused: Bool) {
        lock.lock()
        isRecordingPaused = paused
        lock.unlock()
    }

    @MainActor
    func sync(with entries: [SoundEntry]) {
        lock.lock()
        hotkeyMap = [:]
        keyCodeToHotkeys = [:]
        heldEntryIDs.removeAll()

        for entry in entries {
            guard let hotkey = entry.hotkey else { continue }
            hotkeyMap[hotkey] = entry.id
            keyCodeToHotkeys[hotkey.keyCode, default: []].append(hotkey)
        }
        lock.unlock()

        if hotkeyMap.isEmpty {
            removeTap()
        } else {
            installTapIfNeeded()
        }
    }

    @MainActor
    func stop() {
        removeTap()
    }

    @MainActor
    private func installTapIfNeeded() {
        guard eventTap == nil else { return }

        guard AXIsProcessTrusted() else {
            Logger.frok.error("Accessibility permission required for global hotkeys")
            promptForAccessibilityIfNeeded()
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: Self.eventTapCallback,
            userInfo: userInfo
        ) else {
            Logger.frok.error("Failed to create CGEvent tap for global hotkeys")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    @MainActor
    private func removeTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    @MainActor
    private func promptForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func shouldConsume(event: CGEvent, type: CGEventType) -> Bool {
        lock.lock()
        let paused = isRecordingPaused
        lock.unlock()

        if paused {
            return false
        }

        switch type {
        case .keyDown:
            lock.lock()
            var matchingEntryID: UUID?
            for (hotkey, entryID) in hotkeyMap where hotkey.matches(event: event) {
                matchingEntryID = entryID
                break
            }
            lock.unlock()

            guard let entryID = matchingEntryID else { return false }

            Task { @MainActor in
                self.handleKeyDown(entryID: entryID)
            }
            return true

        case .keyUp:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

            lock.lock()
            let hotkeys = keyCodeToHotkeys[keyCode] ?? []
            let entryIDs = hotkeys.compactMap { hotkey -> UUID? in
                guard let entryID = hotkeyMap[hotkey], heldEntryIDs.contains(entryID) else { return nil }
                return entryID
            }
            lock.unlock()

            guard !entryIDs.isEmpty else { return false }

            Task { @MainActor in
                for entryID in entryIDs {
                    self.handleKeyUp(entryID: entryID)
                }
            }
            return true

        default:
            return false
        }
    }

    @MainActor
    private func handleKeyDown(entryID: UUID) {
        lock.lock()
        let alreadyHeld = heldEntryIDs.contains(entryID)
        if !alreadyHeld {
            heldEntryIDs.insert(entryID)
        }
        lock.unlock()

        guard !alreadyHeld else { return }
        soundLibrary.keyDownPlay(id: entryID)
    }

    @MainActor
    private func handleKeyUp(entryID: UUID) {
        lock.lock()
        guard heldEntryIDs.contains(entryID) else {
            lock.unlock()
            return
        }
        heldEntryIDs.remove(entryID)
        lock.unlock()

        soundLibrary.keyUpStop(id: entryID)
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = manager.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if manager.shouldConsume(event: event, type: type) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
