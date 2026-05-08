import SwiftUI

@main
struct SirenApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Mermaid File...") {
                    appState.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Reload File") {
                    appState.reloadFile()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!appState.hasFile)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}
