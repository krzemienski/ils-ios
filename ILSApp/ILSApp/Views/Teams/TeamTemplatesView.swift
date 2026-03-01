import SwiftUI
import ILSShared

struct TeamTemplatesView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState
    @State private var viewModel: TeamsViewModel
    @State private var showCreateSheet = false

    init(apiClient: APIClient) {
        _viewModel = State(wrappedValue: TeamsViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                if viewModel.templates.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.templates) { template in
                        templateCard(template)
                    }
                }
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Team Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            Text("Create Template Sheet")
                .padding()
        }
        .task {
            await viewModel.loadTemplates()
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 64, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Team Templates")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Create reusable templates to quickly set up teams for common workflows")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private func templateCard(_ template: TeamTemplate) -> some View {
        Button {
            // Template selection - will be handled in future subtasks
        } label: {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Text(template.name)
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    if template.isBuiltIn {
                        Text("Built-in")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, theme.spacingSM)
                            .padding(.vertical, theme.spacingXS)
                            .background(theme.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                if let category = template.category, !category.isEmpty {
                    Text(category.uppercased())
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .padding(.bottom, theme.spacingXS)
                }

                if let description = template.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: theme.spacingMD) {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "person.2")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        Text("\(template.members.count)")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.textTertiary)

                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "checklist")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        Text("\(template.tasks.count)")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
    }
}
