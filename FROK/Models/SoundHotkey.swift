import AppKit
import Carbon
import CoreGraphics
import SwiftUI

struct SoundHotkey: Codable, Equatable, Hashable {
    var keyCode: UInt16
    var carbonModifiers: UInt32

    var isValid: Bool {
        guard carbonModifiers & (UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(shiftKey)) != 0 else {
            return false
        }
        return !Self.modifierKeyCodes.contains(keyCode)
    }

    init(keyCode: UInt16, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        let keyCode = UInt16(event.keyCode)
        guard !Self.modifierKeyCodes.contains(keyCode) else { return nil }

        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        guard modifiers & (UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(shiftKey)) != 0 else {
            return nil
        }

        self.keyCode = keyCode
        self.carbonModifiers = modifiers
    }

    func matches(event: CGEvent) -> Bool {
        guard UInt16(event.getIntegerValueField(.keyboardEventKeycode)) == keyCode else { return false }
        return Self.carbonModifiers(from: event.flags) == carbonModifiers
    }

    var modifierFlags: NSEvent.ModifierFlags {
        Self.modifierFlags(from: carbonModifiers)
    }

    var keyDisplayName: String {
        Self.keyDisplayNames[keyCode] ?? "Key \(keyCode)"
    }

    var orderedModifierSymbols: [String] {
        var symbols: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { symbols.append("control") }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols.append("option") }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols.append("shift") }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols.append("command") }
        return symbols
    }

    private static let modifierKeyCodes: Set<UInt16> = [
        UInt16(kVK_Shift),
        UInt16(kVK_RightShift),
        UInt16(kVK_Control),
        UInt16(kVK_RightControl),
        UInt16(kVK_Option),
        UInt16(kVK_RightOption),
        UInt16(kVK_Command),
        UInt16(kVK_RightCommand),
        UInt16(kVK_Function),
    ]

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private static func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.maskCommand) { result |= UInt32(cmdKey) }
        if flags.contains(.maskAlternate) { result |= UInt32(optionKey) }
        if flags.contains(.maskControl) { result |= UInt32(controlKey) }
        if flags.contains(.maskShift) { result |= UInt32(shiftKey) }
        return result
    }

    private static func modifierFlags(from carbonModifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        return flags
    }

    private static let keyDisplayNames: [UInt16: String] = [
        UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_C): "C",
        UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F",
        UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_I): "I",
        UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
        UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_O): "O",
        UInt16(kVK_ANSI_P): "P", UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_R): "R",
        UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_U): "U",
        UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_X): "X",
        UInt16(kVK_ANSI_Y): "Y", UInt16(kVK_ANSI_Z): "Z",
        UInt16(kVK_ANSI_0): "0", UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2",
        UInt16(kVK_ANSI_3): "3", UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_5): "5",
        UInt16(kVK_ANSI_6): "6", UInt16(kVK_ANSI_7): "7", UInt16(kVK_ANSI_8): "8",
        UInt16(kVK_ANSI_9): "9",
        UInt16(kVK_Space): "Space", UInt16(kVK_Return): "Return", UInt16(kVK_Tab): "Tab",
        UInt16(kVK_Escape): "Esc", UInt16(kVK_Delete): "Delete", UInt16(kVK_ForwardDelete): "Fwd Del",
        UInt16(kVK_UpArrow): "↑", UInt16(kVK_DownArrow): "↓",
        UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→",
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3", UInt16(kVK_F4): "F4",
        UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6", UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8",
        UInt16(kVK_F9): "F9", UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
        UInt16(kVK_ANSI_Minus): "-", UInt16(kVK_ANSI_Equal): "=", UInt16(kVK_ANSI_LeftBracket): "[",
        UInt16(kVK_ANSI_RightBracket): "]", UInt16(kVK_ANSI_Backslash): "\\",
        UInt16(kVK_ANSI_Semicolon): ";", UInt16(kVK_ANSI_Quote): "'", UInt16(kVK_ANSI_Comma): ",",
        UInt16(kVK_ANSI_Period): ".", UInt16(kVK_ANSI_Slash): "/", UInt16(kVK_ANSI_Grave): "`",
    ]
}

struct HotkeyDisplayView: View {
    let hotkey: SoundHotkey

    var body: some View {
        HStack(spacing: 0) {
            Group {
                ForEach(hotkey.orderedModifierSymbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                }
                Text(hotkey.keyDisplayName)
            }
            .minimumScaleFactor(0.5)
            .font(.system(size: 10, weight: .medium))
        }
    }
}
