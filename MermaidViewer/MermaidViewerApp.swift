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
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}
