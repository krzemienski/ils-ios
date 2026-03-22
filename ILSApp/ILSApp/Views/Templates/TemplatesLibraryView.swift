import SwiftUI
import ILSShared

// MARK: - TemplatesLibraryView

/// A searchable list of all session templates organised into "Built-in" and
/// "My Templates" sections.
///
/// The view is designed to be presented as a sheet so the caller can apply a
/// template with a single tap — row taps invoke ``onSelect`` and dismiss the
/// sheet automatically. The toolbar "+" button opens ``EditTemplateView`` to
/// create a new user template. User templates support swipe-to-delete; built-in
/// templates are protected and cannot be removed.
///
/// ## Lifecycle
/// On first appearance the view configures ``TemplatesViewModel`` with the
/// shared `APIClient` and calls `loadTemplates()` to populate the list.
///
/// ## Topics
/// ### Inputs
/// - ``onSelect`` — Called with the chosen template; the sheet is dismissed immediately after.
///
/// ### State
/// - ``viewModel`` — Observable view model managing template data and search text
/// - ``showingNewTemplate`` — Controls the "New Template" editor sheet
struct TemplatesLibraryView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Called when the user taps a template row. The sheet is dismissed immediately after.
    let onSelect: (SessionTemplate) -> Void

    /// Observable view model managing the template list, search, and API calls.
    @State private var viewModel = TemplatesViewModel()
    /// Controls presentation of the new-template editor sheet.
    @State private var showingNewTemplate = false

    // MARK: - Computed Helpers

    /// Built-in templates filtered by the current search text.
    private var filteredBuiltIn: [SessionTemplate] {
        viewModel.filteredTemplates.filter { $0.isBuiltIn }
    }

    /// User-created templates filtered by the current search text.
    private var filteredUser: [SessionTemplate] {
        viewModel.filteredTemplates.filter { !$0.isBuiltIn }
    }

    // MARK: - Body

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            List {
                if let error = viewModel.error {
                    ErrorStateView(error: error) {
                        await viewModel.loadTemplates()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    builtInSection
                    myTemplatesSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Templates")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .searchable(text: $vm.searchText, prompt: "Search templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(theme.textSecondary)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTemplate = true
                    } label: {
                        Label("New Template", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.templates.isEmpty {
                    ProgressView("Loading templates...")
                } else if viewModel.templates.isEmpty && !viewModel.isLoading && viewModel.error == nil {
                    EmptyStateView(
                        title: "No Templates",
                        systemImage: "doc.text",
                        description: "Create a template to quickly start sessions with pre-configured settings",
                        actionTitle: "New Template"
                    ) {
                        showingNewTemplate = true
                    }
                }
            }
            .sheet(isPresented: $showingNewTemplate) {
                NavigationStack {
                    EditTemplateView(template: nil, viewModel: viewModel)
                }
            }
            .task {
                viewModel.configure(client: appState.apiClient)
                await viewModel.loadTemplates()
            }
        }
    }

    // MARK: - Sections

    /// "Built-in" section — read-only templates shipped with the app.
    @ViewBuilder
    private var builtInSection: some View {
        if !filteredBuiltIn.isEmpty {
            Section("Built-in") {
                ForEach(filteredBuiltIn) { template in
                    TemplateRow(template: template) {
                        Task { await viewModel.toggleFavorite(id: template.id) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(template)
                        dismiss()
                    }
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    /// "My Templates" section — user-created templates that support swipe-to-delete.
    @ViewBuilder
    private var myTemplatesSection: some View {
        Section("My Templates") {
            ForEach(filteredUser) { template in
                TemplateRow(template: template) {
                    Task { await viewModel.toggleFavorite(id: template.id) }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(template)
                    dismiss()
                }
                .accessibilityAddTraits(.isButton)
            }
            .onDelete(perform: deleteUserTemplate)

            if filteredUser.isEmpty && !viewModel.isLoading {
                Text("No custom templates yet")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: - Actions

    private func deleteUserTemplate(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let template = filteredUser[index]
                await viewModel.deleteTemplate(id: template.id)
            }
        }
    }
}
