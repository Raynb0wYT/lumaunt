import SwiftUI
import AppKit

@main
struct MyApp: App {

    @State private var appState = AppState()
    @AppStorage("usesSystemAppearance") private var usesSystemAppearance = true
    @AppStorage("isDarkMode") private var isDarkMode = false

    init() {
        CrashReporting.configureFromStoredPreference()

        let defaults = UserDefaults.standard
        let followsSystem =
            defaults.object(forKey: "usesSystemAppearance") as? Bool ?? true
        let usesDarkMode = defaults.bool(forKey: "isDarkMode")

        Self.applyAppearance(
            followsSystem: followsSystem,
            usesDarkMode: usesDarkMode
        )
    }

    var body: some Scene {

        // MARK: - Main Window

        WindowGroup(id: "main") {
            ContentView(appState: appState)
                .frame(minWidth: 560, minHeight: 480)
                .onChange(of: usesSystemAppearance, initial: true) {
                    updateAppearance()
                }
                .onChange(of: isDarkMode) {
                    updateAppearance()
                }
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandMenu("Presence") {
                Button("Apply Presence") { Task { await appState.applyPresence() } }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(appState.isApplyingPresence || HostedImageStore.shared.isDeleting)
                Button("Disable Presence") { appState.clearPresence() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .disabled(!appState.discord.hasActivePresence || appState.isApplyingPresence)
            }
        }
        // MARK: - Menu Bar

        MenuBarExtra {
            LumauntMenuBarView(appState: appState)
        } label: {
            Image("LumauntMenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel("Lumaunt")
        }
        .menuBarExtraStyle(.window)
        }

    private func updateAppearance() {
        Self.applyAppearance(
            followsSystem: usesSystemAppearance,
            usesDarkMode: isDarkMode
        )
    }

    private static func applyAppearance(
        followsSystem: Bool,
        usesDarkMode: Bool
    ) {
        NSApplication.shared.appearance = followsSystem
            ? nil
            : NSAppearance(
                named: usesDarkMode ? .darkAqua : .aqua
            )
    }
}
