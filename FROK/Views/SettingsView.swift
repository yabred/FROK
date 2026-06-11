import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginManager
    @State private var tableHeight: CGFloat = 0

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
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .onAppear {
            launchAtLogin.refreshStatus()
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
            Text("Sound")
                .padding(.top, 16)
            Text("Sound")
                .padding(.top, 16)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(LaunchAtLoginManager.shared)
}
