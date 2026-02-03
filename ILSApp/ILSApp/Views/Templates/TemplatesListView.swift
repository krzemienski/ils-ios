import SwiftUI
import ILSShared

struct TemplatesListView: View {
    @StateObject private var viewModel = TemplatesViewModel()
    @State private var showingNewTemplate = false

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.retryLoadTemplates()
                }
            } else if viewModel.filteredTemplates.isEmpty && !viewModel.isLoading {
                if viewModel.searchQuery.isEmpty {
                    EmptyStateView(
                        title: "No Templates",
                        systemImage: "doc.text.fill",
                        description: "Create custom session templates with predefined settings",
                        actionTitle: "Create Template"
                    ) {
                        showingNewTemplate = true
                    }
                    .accessibilityIdentifier("empty-templates-state")
                } else {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                }
            } else {
                // Favorite templates section
                if !viewModel.favoriteTemplates.isEmpty {
                    Section(header: Text("Favorites")) {
                        ForEach(viewModel.favoriteTemplates) { template in
                            NavigationLink(value: template) {
                                TemplateRowView(template: template, viewModel: viewModel)
                            }
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("template-\(template.id)")
                        }
                    }
                }

                // Regular templates section
                if !viewModel.regularTemplates.isEmpty {
                    Section(header: viewModel.favoriteTemplates.isEmpty ? Text("Templates") : Text("Other Templates")) {
                        ForEach(viewModel.regularTemplates) { template in
                            NavigationLink(value: template) {
                                TemplateRowView(template: template, viewModel: viewModel)
                            }
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("template-\(template.id)")
                        }
                        .onDelete { offsets in
                            deleteTemplate(at: offsets, from: viewModel.regularTemplates)
                        }
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .searchable(text: $viewModel.searchQuery, prompt: "Search templates...")
        .refreshable {
            await viewModel.loadTemplates()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewTemplate = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("add-template-button")
            }
        }
        .sheet(isPresented: $showingNewTemplate) {
            NewTemplateView { template in
                viewModel.templates.insert(template, at: 0)
            }
        }
        .navigationDestination(for: SessionTemplate.self) { template in
            TemplateDetailView(template: template, viewModel: viewModel)
        }
        .overlay {
            if viewModel.isLoading && viewModel.templates.isEmpty {
                ProgressView("Loading templates...")
                    .accessibilityIdentifier("loading-templates-indicator")
            }
        }
        .task {
            await viewModel.loadTemplates()
        }
        .accessibilityIdentifier("templates-list")
    }

    private func deleteTemplate(at offsets: IndexSet, from templates: [SessionTemplate]) {
        Task {
            for index in offsets {
                let template = templates[index]
                await viewModel.deleteTemplate(template)
            }
        }
    }
}

struct TemplateRowView: View {
    let template: SessionTemplate
    @ObservedObject var viewModel: TemplatesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
            HStack {
                Text(template.name)
                    .font(ILSTheme.headlineFont)
                    .lineLimit(1)

                Spacer()

                // Favorite button
                Button {
                    Task {
                        await viewModel.toggleFavorite(template)
                    }
                } label: {
                    Image(systemName: template.isFavorite ? "star.fill" : "star")
                        .foregroundColor(template.isFavorite ? .yellow : ILSTheme.secondaryText)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("favorite-\(template.id)")

                // Model badge
                Text(template.model)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusS)
            }

            if let description = template.description {
                Text(description)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .lineLimit(2)
            }

            // Tags
            if !template.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ILSTheme.spacingXS) {
                        ForEach(template.tags.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ILSTheme.accent.opacity(0.15))
                                .foregroundColor(ILSTheme.accent)
                                .cornerRadius(ILSTheme.cornerRadiusS)
                        }
                    }
                }
            }

            // Footer with metadata
            HStack(spacing: ILSTheme.spacingS) {
                Label(template.permissionMode.rawValue, systemImage: "lock.shield")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)

                if template.isDefault {
                    Text("Default")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ILSTheme.info)
                        .cornerRadius(ILSTheme.cornerRadiusS)
                }

                Spacer()

                Text(formattedDate(template.updatedAt))
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
            }
        }
        .padding(.vertical, ILSTheme.spacingXS)
        .shadow(color: ILSTheme.shadowLight, radius: 2, x: 0, y: 1)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Template Detail View

struct TemplateDetailView: View {
    let template: SessionTemplate
    @ObservedObject var viewModel: TemplatesViewModel
    @State private var showingEditor = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ILSTheme.spacingM) {
                // Header with metadata
                templateHeader

                Divider()

                // Initial prompt section
                if let initialPrompt = template.initialPrompt, !initialPrompt.isEmpty {
                    VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
                        Text("Initial Prompt")
                            .font(ILSTheme.headlineFont)
                            .foregroundColor(ILSTheme.primaryText)

                        Text(initialPrompt)
                            .font(ILSTheme.bodyFont)
                            .foregroundColor(ILSTheme.secondaryText)
                            .padding(ILSTheme.spacingM)
                            .background(ILSTheme.secondaryBackground)
                            .cornerRadius(ILSTheme.cornerRadiusM)
                    }
                } else {
                    ContentUnavailableView(
                        "No Initial Prompt",
                        systemImage: "text.bubble",
                        description: Text("This template has no predefined initial prompt")
                    )
                }
            }
            .padding(ILSTheme.spacingM)
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task {
                            await viewModel.toggleFavorite(template)
                        }
                    } label: {
                        Label(
                            template.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: template.isFavorite ? "star.slash" : "star"
                        )
                    }

                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit Template", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Template", systemImage: "trash")
                    }
                    .disabled(template.isDefault)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            EditTemplateView(template: template, viewModel: viewModel)
        }
        .alert("Delete Template", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteTemplate(template)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(template.name)'? This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var templateHeader: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
            // Title and favorite
            HStack {
                Text(template.name)
                    .font(ILSTheme.titleFont)

                Spacer()

                if template.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }

            // Description
            if let description = template.description {
                Text(description)
                    .font(ILSTheme.bodyFont)
                    .foregroundColor(ILSTheme.secondaryText)
            }

            // Metadata grid
            VStack(spacing: ILSTheme.spacingS) {
                metadataRow(label: "Model", value: template.model, icon: "cpu")
                metadataRow(label: "Permission Mode", value: template.permissionMode.rawValue, icon: "lock.shield")
                metadataRow(label: "Created", value: formattedDate(template.createdAt), icon: "calendar")
                metadataRow(label: "Updated", value: formattedDate(template.updatedAt), icon: "clock")

                if template.isDefault {
                    metadataRow(label: "Type", value: "Default Template", icon: "star.circle")
                }
            }

            // Tags
            if !template.tags.isEmpty {
                VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
                    Label("Tags", systemImage: "tag")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)

                    FlowLayout(spacing: ILSTheme.spacingXS) {
                        ForEach(template.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ILSTheme.accent.opacity(0.15))
                                .foregroundColor(ILSTheme.accent)
                                .cornerRadius(ILSTheme.cornerRadiusS)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metadataRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.tertiaryText)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)

            Spacer()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Placeholder Views

struct NewTemplateView: View {
    var onCreate: (SessionTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("New Template Form")
                .navigationTitle("New Template")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct EditTemplateView: View {
    let template: SessionTemplate
    @ObservedObject var viewModel: TemplatesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Edit Template Form")
                .navigationTitle("Edit Template")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)

                if currentX + subviewSize.width > width && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += subviewSize.width + spacing
                lineHeight = max(lineHeight, subviewSize.height)
                size.width = max(size.width, currentX - spacing)
            }

            size.height = currentY + lineHeight
            self.size = size
            self.positions = positions
        }
    }
}

#Preview {
    NavigationStack {
        TemplatesListView()
    }
}
