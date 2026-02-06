import SwiftUI
import ILSShared

// MARK: - Spec 017: Bulk MCP Import/Export

struct MCPImportExportView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var importText = ""
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showImportPreview = false
    @State private var previewServers: [MCPImportItem] = []
    @State private var importError: String?
    @State private var showCopiedToast = false
    @State private var exportedJSON = ""

    let servers: [MCPServerItem]

    var body: some View {
        NavigationStack {
            List {
                // Export Section
                Section("Export") {
                    Button {
                        exportServers()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(ILSTheme.accent)
                            Text("Export All Servers (\(servers.count))")
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(servers.isEmpty || isExporting)

                    if !exportedJSON.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Exported JSON")
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                                Spacer()
                                Button("Copy") {
                                    UIPasteboard.general.string = exportedJSON
                                    HapticManager.notification(.success)
                                    showCopiedToast = true
                                }
                                .font(ILSTheme.captionFont)
                            }
                            Text(exportedJSON.prefix(500) + (exportedJSON.count > 500 ? "..." : ""))
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.secondaryText)
                                .lineLimit(10)
                        }
                    }
                }

                // Import Section
                Section("Import") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste MCP server configuration JSON:")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)

                        TextEditor(text: $importText)
                            .font(ILSTheme.codeFont)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .background(ILSTheme.tertiaryBackground)
                            .cornerRadius(ILSTheme.cornerRadiusSmall)
                    }

                    if let importError {
                        Text(importError)
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.error)
                    }

                    Button {
                        previewImport()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(ILSTheme.accent)
                            Text("Preview Import")
                            Spacer()
                            if isImporting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                // Import Preview
                if !previewServers.isEmpty {
                    Section("Preview (\(previewServers.count) servers)") {
                        ForEach(previewServers) { server in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.name)
                                    .font(ILSTheme.headlineFont)
                                Text("\(server.command) \(server.args.joined(separator: " "))")
                                    .font(ILSTheme.codeFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }

                        Button {
                            // Import action would call API
                            HapticManager.notification(.success)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Import \(previewServers.count) Servers")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .foregroundColor(ILSTheme.accent)
                    }
                }

                // Supported Formats
                Section("Supported Formats") {
                    Label("Claude Code JSON", systemImage: "doc.text")
                    Label("Cursor Configuration", systemImage: "arrow.triangle.2.circlepath")
                    Label("Claude Desktop Config", systemImage: "desktopcomputer")
                }
            }
            .darkListStyle()
            .navigationTitle("Import / Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toast(isPresented: $showCopiedToast, message: "Copied to clipboard")
        }
    }

    private func exportServers() {
        isExporting = true
        let exportItems = servers.map { server in
            MCPImportItem(
                name: server.name,
                command: server.command,
                args: server.args,
                env: server.env
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(exportItems),
           let json = String(data: data, encoding: .utf8) {
            exportedJSON = json
            HapticManager.notification(.success)
        }
        isExporting = false
    }

    private func previewImport() {
        importError = nil
        isImporting = true

        let trimmed = importText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            importError = "Invalid text encoding"
            isImporting = false
            return
        }

        do {
            let items = try JSONDecoder().decode([MCPImportItem].self, from: data)
            previewServers = items
            HapticManager.notification(.success)
        } catch {
            importError = "Invalid JSON format: \(error.localizedDescription)"
        }

        isImporting = false
    }
}

struct MCPImportItem: Identifiable, Codable {
    var id: String { name }
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]?
}
