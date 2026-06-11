import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .toggleStyle(.checkbox)
            }

            Text("Settings")
                .padding(.top, 16)

            Spacer()

            HStack {
                Spacer()
                Button("Exit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
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
}

#Preview {
    SettingsView()
        .environmentObject(LaunchAtLoginManager.shared)
}
