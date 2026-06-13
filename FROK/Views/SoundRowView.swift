import SwiftUI

struct SoundRowView: View {
    @Environment(SoundLibrary.self) private var soundLibrary

    let entry: SoundEntry
    @Binding var activeRecordingID: UUID?

    private let volumeTicks: [Double] = [0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5]

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            playIndicator
            aliasField
            hotkeyField
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
            soundLibrary.togglePlayback(id: entry.id)
        } label: {
            Image(systemName: entry.playbackState == .playing ? "stop.fill" : "play.fill")
                .foregroundStyle(playIndicatorColor)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .disabled(entry.loadStatus != .loaded)
    }

    private var playIndicatorColor: Color {
        switch entry.playbackState {
        case .idle:
            .secondary
        case .playing:
            .blue
        case .stoppedFlash:
            .red
        }
    }

    private var aliasField: some View {
        TextField("Alias", text: soundLibrary.aliasBinding(for: entry.id))
            .textFieldStyle(.roundedBorder)
            .frame(width: 100)
    }

    private var hotkeyField: some View {
        HotkeyRecorderField(entryID: entry.id, activeRecordingID: $activeRecordingID)
    }

    private var volumeControl: some View {
        VStack(spacing: 2) {
            Slider(
                value: soundLibrary.volumeBinding(for: entry.id),
                in: 0...1.5,
                step: 0.05
            )
            .frame(width: 160)

            HStack(spacing: 0) {
                ForEach(volumeTicks, id: \.self) { tick in
                    Text("\(Int(tick * 100))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 160)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            soundLibrary.remove(id: entry.id)
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let entry = SoundEntry(
        alias: "Applause",
        bookmarkData: Data(),
        volume: 0.75,
        hotkey: SoundHotkey(keyCode: 49, carbonModifiers: 256),
        loadStatus: .loaded,
        playbackState: .idle
    )

    SoundRowView(entry: entry, activeRecordingID: .constant(nil))
        .environment(SoundLibrary(previewEntries: [entry]))
        .padding()
        .frame(width: 680)
}
