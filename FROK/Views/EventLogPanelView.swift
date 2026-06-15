import SwiftUI

struct EventLogPanelView: View {
    @Environment(EventLogStore.self) private var eventLog
    @Binding var isPresented: Bool

    @State private var dragOffset: CGSize = .zero
    @State private var isScrolledToBottom = true

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if eventLog.entries.isEmpty {
                emptyState
            } else {
                logList
            }
        }
        .frame(width: 440, height: 500)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .offset(dragOffset)
        .gesture(dragGesture)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .foregroundStyle(.blue)
            Text("Event Log")
                .font(.headline)

            Spacer()

            Button {
                eventLog.clear()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Clear log")

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No events yet")
                .foregroundStyle(.secondary)
                .font(.callout)
            Text("Hotkey presses, socket commands, and UI playback will appear here.")
                .foregroundStyle(.tertiary)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(eventLog.entries) { entry in
                        EventLogRowView(entry: entry, timestampFormatter: Self.timestampFormatter)
                            .id(entry.id)
                        Divider()
                            .padding(.leading, 12)
                    }

                    Color.clear
                        .frame(height: 1)
                        .onAppear { isScrolledToBottom = true }
                        .onDisappear { isScrolledToBottom = false }
                }
            }
            .onAppear {
                isScrolledToBottom = true
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: eventLog.entries.count) { _, _ in
                guard isScrolledToBottom else { return }
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastID = eventLog.entries.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
    }
}

private struct EventLogRowView: View {
    let entry: EventLogEntry
    let timestampFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            sourceIcon
                .frame(width: 18)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(timestampFormatter.string(from: entry.timestamp))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    detailLine
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(timestampFormatter.string(from: entry.timestamp))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    detailLine
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var sourceIcon: some View {
        switch entry.source {
        case .hotkey:
            Image(systemName: "keyboard.fill")
                .foregroundStyle(.orange)
                .help("Hotkey")
        case .socket:
            Image(systemName: "terminal.fill")
                .foregroundStyle(.teal)
                .help("Socket")
        case .ui:
            Image(systemName: "cursorarrow.click.2")
                .foregroundStyle(.purple)
                .help("UI")
        }
    }

    @ViewBuilder
    private var detailLine: some View {
        switch entry.source {
        case .hotkey(let hotkey):
            HStack(spacing: 6) {
                HotkeyDisplayView(hotkey: hotkey)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                playbackBadge
            }

        case .socket(let message):
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                    Text(messageDisplay(message))
                        .font(.system(size: 11, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.teal.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                if !entry.isStop {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                playbackBadge
            }

        case .ui:
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: entry.isStop ? "stop.fill" : "play.fill")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text(entry.isStop ? "Stop" : "Play")
                        .font(.callout)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                playbackBadge
            }
        }
    }

    @ViewBuilder
    private var playbackBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.isStop ? "stop.circle.fill" : "speaker.wave.2.fill")
                .font(.caption2)
                .foregroundStyle(entry.isStop ? .red : .blue)
            Text(entry.playbackLabel)
                .font(.callout)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background((entry.isStop ? Color.red : Color.blue).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func messageDisplay(_ message: String) -> String {
        if message.isEmpty {
            return "(empty)"
        }
        return "\"\(message)\""
    }
}

#Preview {
    EventLogPanelPreview()
}

private struct EventLogPanelPreview: View {
    @State private var store = EventLogStore()

    var body: some View {
        EventLogPanelView(isPresented: .constant(true))
            .environment(store)
            .padding()
            .task {
                store.logHotkey(
                    hotkey: SoundHotkey(keyCode: 49, carbonModifiers: 256),
                    soundAlias: "Bonk"
                )
                store.logSocket(message: "bonk", soundAlias: "Bonk")
                store.logSocket(message: "-stop", soundAlias: nil, isStop: true)
                store.logUI(soundAlias: "Applause")
                store.logSocket(message: "veryverylongbonk", soundAlias: "veryverylongbonk")
                store.logSocket(message: "ultra_very_super_long_bonk", soundAlias: "ultra_very_super_long_bonk")
            }
    }
}
