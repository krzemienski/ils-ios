import SwiftUI

struct SessionTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var templates: [SessionTemplate] = []
    @State private var searchText = ""
    let onSelect: (SessionTemplate) -> Void

    private var filteredTemplates: [SessionTemplate] {
        let sorted = templates.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return a.createdAt > b.createdAt
        }
        if searchText.isEmpty { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTemplates) { template in
                    Button {
                        onSelect(template)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(template.name)
                                        .font(ILSTheme.bodyFont.weight(.medium))
                                        .foregroundColor(ILSTheme.primaryText)
                                    if template.isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundColor(ILSTheme.warning)
                                    }
                                }
                                if !template.description.isEmpty {
                                    Text(template.description)
                                        .font(ILSTheme.captionFont)
                                        .foregroundColor(ILSTheme.secondaryText)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Text(template.model.capitalized)
                                .font(ILSTheme.captionFont)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(EntityType.sessions.color.opacity(0.2))
                                .foregroundColor(EntityType.sessions.color)
                                .cornerRadius(4)
                        }
                    }
                    .listRowBackground(ILSTheme.secondaryBackground)
                    .swipeActions(edge: .trailing) {
                        if !SessionTemplate.defaults.contains(where: { $0.name == template.name }) {
                            Button(role: .destructive) {
                                deleteTemplate(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        Button {
                            toggleFavorite(template)
                        } label: {
                            Label(template.isFavorite ? "Unfavorite" : "Favorite", systemImage: template.isFavorite ? "star.slash" : "star.fill")
                        }
                        .tint(ILSTheme.warning)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search templates")
            .scrollContentBackground(.hidden)
            .background(ILSTheme.background)
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { loadTemplates() }
        }
    }

    private func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: "sessionTemplates"),
           let saved = try? JSONDecoder().decode([SessionTemplate].self, from: data) {
            templates = saved
        } else {
            templates = SessionTemplate.defaults
            saveTemplates()
        }
    }

    private func saveTemplates() {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: "sessionTemplates")
        }
    }

    private func deleteTemplate(_ template: SessionTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }

    private func toggleFavorite(_ template: SessionTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index].isFavorite.toggle()
            saveTemplates()
        }
    }
}
