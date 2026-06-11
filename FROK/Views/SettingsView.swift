import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(SoundLibrary.self) private var soundLibrary
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginManager
    @State private var tableHeight: CGFloat = 0
    @State private var activeRecordingID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .toggleStyle(.checkbox)
            }

            table

            HStack {
                Spacer()
                Button("Exit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .frame(minWidth: 720)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            activeRecordingID = nil
        }
        .onAppear {
            launchAtLogin.refreshStatus()
        }
        .onChange(of: activeRecordingID) { _, newValue in
            soundLibrary.onHotkeyRecordingChanged?(newValue != nil)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }

    var table: some View {
        ScrollView(.vertical) {
            tableContent
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { newHeight in
                    tableHeight = newHeight
                }
        }
        .frame(height: tableHeight)
    }

    private var tableContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sound")
                .padding(.top, 16)

            ForEach(soundLibrary.entries) { entry in
                SoundRowView(entry: entry, activeRecordingID: $activeRecordingID)
            }

            Button("Add new sound") {
                openSoundPicker()
            }
            .frame(maxWidth: .infinity)
            .controlSize(.large)
            .padding(.top, 8)
        }
    }

    private func openSoundPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mp3, .aiff, .wav]

        guard panel.runModal() == .OK else { return }
        soundLibrary.addSounds(from: panel.urls)
    }
}

#Preview {
    SettingsView()
        .environment(SoundLibrary())
        .environmentObject(LaunchAtLoginManager.shared)
}
