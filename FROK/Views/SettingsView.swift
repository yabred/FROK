import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct SettingsView: View {
    @Environment(SoundLibrary.self) private var soundLibrary
    @Environment(MenuBarState.self) private var menuBarState
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginManager
    @EnvironmentObject private var accessibilityPermission: AccessibilityPermissionManager
    @FocusState private var focusedAliasID: UUID?
    @State private var activeRecordingID: UUID?
    @State private var isLogPanelPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)

            if accessibilityPermission.accessState != .granted {
                accessibilityBanner
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            table
        }
        .frame(minWidth: 550)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            activeRecordingID = nil
            focusedAliasID = nil
        }
        .onExitCommand {
            focusedAliasID = nil
        }
        .onAppear {
            launchAtLogin.refreshStatus()
            accessibilityPermission.refreshStatus()
        }
        .onDisappear {
            focusedAliasID = nil
        }
        .onChange(of: menuBarState.isPresented) { _, isPresented in
            if !isPresented {
                focusedAliasID = nil
            }
        }
        .onChange(of: activeRecordingID) { _, newValue in
            soundLibrary.onHotkeyRecordingChanged?(newValue != nil)
        }
    }

    private var header: some View {
        HStack {
            Text("FRO")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.accentColor) +
            Text("g") +
            Text(" K")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.accentColor) +
            Text("eyboard")
            Spacer()
        }
    }
    
    private var accessibilityBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(accessibilityBannerTitle)
                    .foregroundStyle(.red)
                    .font(.callout)

                Text(accessibilityBannerBody)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(accessibilityPermission.bundlePathForDisplay)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text("Bundle ID: \(accessibilityPermission.bundleIdentifierForDisplay)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Button("Open System Settings") {
                    accessibilityPermission.openAccessibilitySettings()
                }
                .controlSize(.small)

                Button("Restart FROK") {
                    accessibilityPermission.restartApp()
                }
                .controlSize(.small)
            }
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

    private var accessibilityBannerTitle: String {
        switch accessibilityPermission.accessState {
        case .granted:
            ""
        case .notGranted:
            "Accessibility access is required for global hotkeys."
        case .stale:
            "Accessibility permission is out of date for this build."
        }
    }

    private var accessibilityBannerBody: String {
        switch accessibilityPermission.accessState {
        case .granted:
            ""
        case .notGranted:
            "Enable FROK for the app path shown below, then restart FROK. Remove older FROK entries from the list if you previously built from Xcode."
        case .stale:
            "Remove FROK from Accessibility, quit FROK, open it again, re-enable access for the path below, then restart FROK."
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

    private var maxTableHeight: CGFloat {
        guard let screenHeight = NSScreen.main?.visibleFrame.height else {
            return .infinity
        }

        var chrome: CGFloat = 76
        if accessibilityPermission.accessState != .granted {
            chrome += 80
        }
        return max(120, screenHeight - chrome)
    }

    var table: some View {
        FloatingFooterScrollView(maxHeight: maxTableHeight) {
            tableContent
        } footer: {
            footerBar
        }
    }

    private var tableContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(soundLibrary.entries) { entry in
                SoundRowView(
                    entry: entry,
                    activeRecordingID: $activeRecordingID,
                    focusedAliasID: $focusedAliasID
                )
            }

            Button("Add new sound") {
                openSoundPicker()
            }
            .frame(maxWidth: .infinity)
            .controlSize(.large)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 16)
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

            Button("Log") {
                isLogPanelPresented.toggle()
            }.popover(isPresented: $isLogPanelPresented) {
                EventLogPanelView(isPresented: $isLogPanelPresented)
            }

            Button("Exit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var footerBar: some View {
        footer
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
    }

    private func openSoundPicker() {
        menuBarState.beginFilePick()
        SoundFilePicker.pick(
            onDisplayed: { menuBarState.notifyPickerDidOpen() },
            onCompletion: { urls in
                menuBarState.endFilePick()
                guard let urls else { return }
                soundLibrary.addSounds(from: urls)
            }
        )
    }
}

private struct FloatingFooterScrollView<Content: View, Footer: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    @State private var contentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    private var totalHeight: CGFloat {
        contentHeight + footerHeight
    }

    private var containerHeight: CGFloat {
        min(totalHeight, maxHeight)
    }

    private var needsScrolling: Bool {
        totalHeight > maxHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            if needsScrolling {
                ScrollView(.vertical) {
                    measuredContent
                }
                .defaultScrollAnchor(.top)
                .frame(maxHeight: max(0, maxHeight - footerHeight))
            } else {
                measuredContent
            }

            footer()
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { newHeight in
                    footerHeight = newHeight
                }
        }
        .frame(height: containerHeight > 0 ? containerHeight : nil, alignment: .top)
    }

    private var measuredContent: some View {
        content()
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { newHeight in
                contentHeight = newHeight
            }
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
    let entry2 = SoundEntry(
        alias: "Bonk",
        bookmarkData: Data(),
        volume: 0.3,
        hotkey: SoundHotkey(keyCode: 43, carbonModifiers: 6912),
        loadStatus: .loading,
        playbackState: .playing
    )
    let entry3 = SoundEntry(
        alias: "Hello",
        bookmarkData: Data(),
        volume: 1.5,
        hotkey: SoundHotkey(keyCode: 49, carbonModifiers: 4608),
        loadStatus: .failed("fail"),
        playbackState: .stoppedFlash
    )
    
    SettingsView()
        .environment(SoundLibrary(previewEntries: [entry, entry2, entry3]))
        .environment(EventLogStore())
        .environment(MenuBarState())
        .environmentObject(LaunchAtLoginManager.shared)
        .environmentObject(AccessibilityPermissionManager.shared)
}
