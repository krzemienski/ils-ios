import SwiftUI
import ILSShared

struct TeamTaskListView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    var viewModel: TeamsViewModel
    let teamName: String
    @State private var showCreateTask = false
    @State private var newTaskSubject = ""
    @State private var newTaskDescription = ""

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    if viewModel.tasks.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.tasks) { task in
                            taskCard(task)
                        }
                    }
                }
                .padding(theme.spacingMD)
            }

            Button {
                showCreateTask = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 56, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .background(
                        Circle()
                            .fill(theme.bgPrimary)
                            .padding(8)
                    )
            }
            .padding(theme.spacingLG)
        }
        .alert("Create Task", isPresented: $showCreateTask) {
            TextField("Subject", text: $newTaskSubject)
            TextField("Description", text: $newTaskDescription)
            Button("Cancel", role: .cancel) {
                resetTaskForm()
            }
            Button("Create") {
                createTask()
            }
            .disabled(newTaskSubject.isEmpty)
        } message: {
            Text("Create a new task for the team")
        }
        .task {
            await viewModel.loadTasks(teamName: teamName)
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "checklist")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Tasks")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Create tasks to organize team work")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func taskCard(_ task: TeamTask) -> some View {
        Button {
            cycleTaskStatus(task)
        } label: {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Text(task.subject)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    statusChip(for: task.status)
                }

                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                if let owner = task.owner, !owner.isEmpty {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "person.circle")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        Text(owner)
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

    private func statusChip(for status: TeamTaskStatus) -> some View {
        let (color, text) = statusInfo(for: status)

        return Text(text)
            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            .foregroundStyle(color)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(theme.cornerRadius)
    }

    private func statusInfo(for status: TeamTaskStatus) -> (Color, String) {
        switch status {
        case .pending:
            return (theme.textTertiary, "Pending")
        case .inProgress:
            return (theme.accent, "In Progress")
        case .completed:
            return (theme.success, "Completed")
        case .deleted:
            return (theme.error, "Deleted")
        }
    }

    private func cycleTaskStatus(_ task: TeamTask) {
        let nextStatus: TeamTaskStatus
        switch task.status {
        case .pending:
            nextStatus = .inProgress
        case .inProgress:
            nextStatus = .completed
        case .completed, .deleted:
            nextStatus = .pending
        }

        Task {
            await viewModel.updateTask(teamName: teamName, id: task.id, status: nextStatus, owner: nil)
        }
    }

    private func createTask() {
        Task {
            await viewModel.createTask(teamName: teamName, subject: newTaskSubject, description: newTaskDescription)
            resetTaskForm()
        }
    }

    private func resetTaskForm() {
        newTaskSubject = ""
        newTaskDescription = ""
    }
}
