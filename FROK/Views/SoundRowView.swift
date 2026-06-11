import SwiftUI

struct SoundRowView: View {
    @Environment(SoundLibrary.self) private var soundLibrary

    let entry: SoundEntry

    private let volumeTicks: [Double] = [0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5]

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            playIndicator
            aliasField
            pathLabel
            volumeControl
            deleteButton
        }
        .padding(.vertical, 6)
    }

    private var statusIcon: some View {
        Group {
            switch entry.loadStatus {
            case .loaded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
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
            Circle()
                .fill(playIndicatorColor)
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
            .green
        case .stoppedFlash:
            .red
        }
    }

    private var aliasField: some View {
        TextField("Alias", text: soundLibrary.aliasBinding(for: entry.id))
            .textFieldStyle(.roundedBorder)
            .frame(width: 100)
    }

    private var pathLabel: some View {
        Text(displayPath)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(width: 140, alignment: .leading)
    }

    private var displayPath: String {
        if let url = soundLibrary.resolvedURL(for: entry.id) {
            return SoundPathFormatting.truncatedPath(url)
        }
        return "..."
    }

    private var volumeControl: some View {
        VStack(spacing: 2) {
            Slider(
                value: soundLibrary.volumeBinding(for: entry.id),
                in: 0 ... 1.5,
                step: 0.01
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
