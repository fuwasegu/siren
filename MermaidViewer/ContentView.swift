import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.hasFile {
                MermaidCanvasView(mermaidContent: appState.mermaidContent, theme: appState.theme, reloadToken: appState.reloadToken)
                    .environmentObject(appState)
                    .ignoresSafeArea()

                // File name badge
                VStack {
                    HStack {
                        Spacer()

                        HStack(spacing: 8) {
                            Text(appState.fileName)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)

                            Button(action: { appState.reloadFile() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Reload file (⌘R)")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(16)
                    }
                    Spacer()
                }
            } else {
                DropZoneView()
            }

            // Error banner (visible in both states)
            if let error = appState.loadError {
                VStack {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(16)
                    Spacer()
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .preferredColorScheme(appState.theme.colorScheme)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            let ext = url.pathExtension.lowercased()
            if ext == "mermaid" || ext == "mmd" || ext == "txt" {
                appState.loadFile(url: url)
            }
        }
        return true
    }
}

struct DropZoneView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 100, height: 100)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("Open a Mermaid Diagram")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Drop a .mermaid or .mmd file here, or click to open")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Button(action: { appState.openFile() }) {
                Label("Open File", systemImage: "folder")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)

            Text("⌘O")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
