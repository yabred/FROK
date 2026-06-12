import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(SoundLibrary.self) private var soundLibrary
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginManager
    @EnvironmentObject private var accessibilityPermission: AccessibilityPermissionManager
    @State private var tableHeight: CGFloat = 0
    @State private var activeRecordingID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !accessibilityPermission.isTrusted {
                accessibilityBanner
                    .padding(.top, 8)
            }

            table

            footer
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
            accessibilityPermission.refreshStatus()
        }
        .onChange(of: activeRecordingID) { _, newValue in
            soundLibrary.onHotkeyRecordingChanged?(newValue != nil)
        }
    }

    private var header: some View {
        HStack {
            Text("FRO")
                .font(.title)
                .fontWeight(.bold) +
            Text("g") +
            Text(" K")
                .font(.title)
                .fontWeight(.bold) +
            Text("eyboard")
            Spacer()
        }
    }
    
    private var accessibilityBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text("Accessibility access is required for global hotkeys.")
                    .foregroundStyle(.red)
                    .font(.callout)
                Text(accessibilityPermission.bundlePathForDisplay)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 8)

            Button("Open System Settings") {
                accessibilityPermission.openAccessibilitySettings()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.15))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
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
        .padding(.top, 16)
    }

    private var tableContent: some View {
        VStack(alignment: .leading, spacing: 0) {
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

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle("Launch at login", isOn: launchAtLoginBinding)
                .toggleStyle(.checkbox)
            
            Spacer()
            
            Text("Version \(appVersion)")
                .foregroundStyle(.secondary)
                .font(.caption)
            
            Text("Loaded sounds: \(soundLibrary.formattedLoadedMemoryUsage)")
                .foregroundStyle(.secondary)
                .font(.caption)
            
            Button("Exit") {
                NSApplication.shared.terminate(nil)
            }
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
        .environmentObject(AccessibilityPermissionManager.shared)
}
