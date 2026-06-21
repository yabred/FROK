import AppKit
import SwiftUI

@MainActor
struct SoundRowView: View {
    @Environment(SoundLibrary.self) private var soundLibrary
    @Environment(EventLogStore.self) private var eventLog

    let entry: SoundEntry
    @Binding var activeRecordingID: UUID?
    var focusedAliasID: FocusState<UUID?>.Binding

    private let volumeTicks: [Double] = [0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5]

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            playIndicator
            aliasField
            hotkeyField
            playbackModeControl
            volumeControl
            deleteButton
        }
        .padding(.vertical, 6)
    }

    private var statusIcon: some View {
        Group {
            switch entry.loadStatus {
            case .loaded:
                Color(.clear)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .loading:
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: 20)
    }

    private var playIndicator: some View {
        Button {
            let isStop = entry.playbackState == .playing
            eventLog.logUI(soundAlias: entry.alias, isStop: isStop)
            soundLibrary.togglePlayback(id: entry.id)
        } label: {
            Image(systemName: entry.playbackState == .playing ? "stop.fill" : "play.fill")
                .foregroundStyle(playIndicatorColor)
                .frame(width: 16, height: 16)
                .padding(4)
        }
        .buttonStyle(.plain)
        .disabled(entry.loadStatus != .loaded)
    }

    private var playIndicatorColor: Color {
        switch entry.playbackState {
        case .idle: .secondary
        case .playing: .accentColor
        case .stoppedFlash: .red
        }
    }

    private var aliasField: some View {
        TextField("Alias", text: soundLibrary.aliasBinding(for: entry.id))
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
            .focused(focusedAliasID, equals: entry.id)
    }

    private var hotkeyField: some View {
        HotkeyRecorderField(entryID: entry.id, activeRecordingID: $activeRecordingID)
    }

    private var playbackModeControl: some View {
        PlaybackModeSegmentedPicker(selection: soundLibrary.playbackModeBinding(for: entry.id))
            .scaleEffect(CGSize(width: 0.75, height: 0.75))
            .frame(maxWidth: 66)
    }

    private var volumeControl: some View {
        VStack(spacing: 2) {
            Slider(
                value: soundLibrary.volumeBinding(for: entry.id),
                in: 0...1.5,
                step: 0.05
            )
            .frame(width: 130)

            HStack(spacing: 0) {
                ForEach(volumeTicks, id: \.self) { tick in
                    Text("\(Int(tick * 100))")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 130)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            soundLibrary.remove(id: entry.id)
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

#Preview {
    struct PreviewContainer: View {
        @FocusState private var focusedAliasID: UUID?

        var body: some View {
            let entry = SoundEntry(
                alias: "Applause",
                bookmarkData: Data(),
                volume: 0.75,
                hotkey: SoundHotkey(keyCode: 49, carbonModifiers: 256),
                loadStatus: .loaded,
                playbackState: .idle
            )

            SoundRowView(
                entry: entry,
                activeRecordingID: .constant(nil),
                focusedAliasID: $focusedAliasID
            )
            .environment(SoundLibrary(previewEntries: [entry]))
            .environment(EventLogStore())
            .padding()
            .frame(width: 840)
        }
    }

    return PreviewContainer()
}

private struct PlaybackModeSegmentedPicker: NSViewRepresentable {
    @Binding var selection: SoundPlaybackMode

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let modes = SoundPlaybackMode.allCases
        let control = NSSegmentedControl(
            labels: modes.map(\.label),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.changed(_:))
        )
        applyTooltips(to: control, modes: modes)
        syncSelection(on: control)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        applyTooltips(to: control, modes: SoundPlaybackMode.allCases)
        syncSelection(on: control)
    }

    private func syncSelection(on control: NSSegmentedControl) {
        guard let index = SoundPlaybackMode.allCases.firstIndex(of: selection) else { return }
        control.selectedSegment = index
    }

    private func applyTooltips(to control: NSSegmentedControl, modes: [SoundPlaybackMode]) {
        for (index, mode) in modes.enumerated() {
            control.setToolTip(mode.tooltip, forSegment: index)
        }
    }

    final class Coordinator: NSObject {
        var selection: Binding<SoundPlaybackMode>

        init(selection: Binding<SoundPlaybackMode>) {
            self.selection = selection
        }

        @objc func changed(_ sender: NSSegmentedControl) {
            let modes = SoundPlaybackMode.allCases
            let index = sender.selectedSegment
            guard modes.indices.contains(index) else { return }
            selection.wrappedValue = modes[index]
        }
    }
}
