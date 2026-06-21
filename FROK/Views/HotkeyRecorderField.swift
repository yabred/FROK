import AppKit
import Carbon
import SwiftUI

@MainActor
struct HotkeyRecorderField: View {
    @Environment(SoundLibrary.self) private var soundLibrary

    let entryID: UUID
    @Binding var activeRecordingID: UUID?

    @State private var showsConflict = false
    @State private var localMonitor: Any?

    private var hotkey: SoundHotkey? {
        soundLibrary.entries.first(where: { $0.id == entryID })?.hotkey
    }

    private var isRecording: Bool {
        activeRecordingID == entryID
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(alignment: .center, spacing: 4) {
                if let hotkey {
                    HotkeyDisplayView(hotkey: hotkey)
                } else if !isRecording {
                    Text("Record Key")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, hotkey == nil ? 6 : 28)
            .frame(width: 100, height: 24)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .textBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .highPriorityGesture(
                TapGesture().onEnded {
                    activeRecordingID = entryID
                }
            )

            if hotkey != nil {
                Button {
                    _ = soundLibrary.updateHotkey(id: entryID, hotkey: nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color(nsColor: .separatorColor).opacity(0.35)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
        }
        .onChange(of: isRecording) { _, recording in
            if recording {
                startRecording()
            } else {
                stopRecording()
            }
        }
        .onChange(of: activeRecordingID) { _, _ in
            if !isRecording {
                stopRecording()
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var borderColor: Color {
        if showsConflict {
            .red
        } else if isRecording {
            .accentColor
        } else {
            Color(nsColor: .separatorColor)
        }
    }

    private var borderWidth: CGFloat {
        if showsConflict || isRecording {
            3
        } else {
            1
        }
    }

    private func startRecording() {
        stopRecording()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                activeRecordingID = nil
                return nil
            }

            guard let recorded = SoundHotkey(event: event), recorded.isValid else {
                flashConflict()
                return nil
            }

            guard soundLibrary.updateHotkey(id: entryID, hotkey: recorded) else {
                flashConflict()
                return nil
            }

            activeRecordingID = nil
            return nil
        }
    }

    private func stopRecording() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func flashConflict() {
        showsConflict = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            showsConflict = false
        }
    }
}
