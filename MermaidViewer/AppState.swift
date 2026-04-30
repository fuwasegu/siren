import SwiftUI
import UniformTypeIdentifiers

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    func next() -> AppTheme {
        switch self {
        case .system: return .light
        case .light: return .dark
        case .dark: return .system
        }
    }
}

class AppState: ObservableObject {
    @Published var mermaidContent: String = ""
    @Published var fileName: String = ""
    @Published var hasFile: Bool = false
    @Published var theme: AppTheme = .system

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "mermaid") ?? .plainText,
            UTType(filenameExtension: "mmd") ?? .plainText,
            .plainText
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a Mermaid diagram file"

        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url: url)
        }
    }

    func loadFile(url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            DispatchQueue.main.async {
                self.mermaidContent = content
                self.fileName = url.lastPathComponent
                self.hasFile = true
            }
        } catch {
            print("Failed to load file: \(error)")
        }
    }
}
