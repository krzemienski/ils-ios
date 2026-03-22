import SwiftUI
import ILSShared

/// Zoomable, pannable visualization of a session's fork lineage.
///
/// Shows the complete fork tree for a session family, with session nodes color-coded by
/// status and connected by bezier curves representing the fork relationship. Supports
/// pinch-to-zoom and scroll-to-pan. A comparison mode lets users select two branches to
/// highlight their divergence path.
///
/// ## Topics
/// ### Initialization
/// - ``init(initialSession:onNavigate:)``
struct SessionForkTreeView: View {
    let initialSession: ChatSession
    let onNavigate: (ChatSession) -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var viewModel = SessionForkTreeViewModel()
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    // Layout constants — mirror SessionForkTreeViewModel.Layout
    private let nodeWidth: CGFloat = 200
    private let nodeHeight: CGFloat = 100

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading fork tree...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if viewModel.sessions.isEmpty {
                emptyView
            } else {
                canvasView
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Fork Tree")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: theme.spacingSM) {
                    compareButton
                    resetZoomButton
                }
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadForkTree(sessionId: initialSession.id)
        }
    }

    // MARK: - Toolbar Buttons

    private var compareButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.isComparisonMode.toggle()
                if !viewModel.isComparisonMode {
                    viewModel.comparisonSelections.removeAll()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(
                    systemName: viewModel.isComparisonMode
                        ? "arrow.triangle.branch"
                        : "arrow.triangle.branch"
                )
                Text(viewModel.isComparisonMode ? "Comparing" : "Compare")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            }
            .foregroundStyle(viewModel.isComparisonMode ? theme.warning : theme.textSecondary)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, 4)
            .background(
                (viewModel.isComparisonMode ? theme.warning : theme.textSecondary)
                    .opacity(0.1)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var resetZoomButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                scale = 1.0
                lastScale = 1.0
            }
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .foregroundStyle(scale == 1.0 ? theme.textTertiary : theme.textSecondary)
        }
        .buttonStyle(.plain)
        .disabled(scale == 1.0)
    }

    // MARK: - Error View

    private func errorView(error: Error) -> some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(theme.warning)
            Text("Failed to load fork tree")
                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text(error.localizedDescription)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadForkTree(sessionId: initialSession.id) }
            }
            .font(.system(size: theme.fontBody, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
        }
        .padding(theme.spacingLG)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "arrow.triangle.branch")
                .font(.largeTitle)
                .foregroundStyle(theme.textTertiary)
            Text("No sessions in fork tree")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Canvas View

    private var canvasView: some View {
        VStack(spacing: 0) {
            infoHeader
            Divider()
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Background dot grid
                    gridBackground
                        .frame(
                            width: viewModel.canvasSize.width,
                            height: viewModel.canvasSize.height
                        )

                    // Connection lines drawn below nodes
                    connectionLines
                        .frame(
                            width: viewModel.canvasSize.width,
                            height: viewModel.canvasSize.height
                        )
                        .allowsHitTesting(false)

                    // Session node cards
                    ForEach(viewModel.sessions) { session in
                        if let position = viewModel.nodePositions[session.id] {
                            nodeCard(for: session)
                                .position(x: position.x, y: position.y)
                        }
                    }
                }
                .frame(
                    width: viewModel.canvasSize.width,
                    height: viewModel.canvasSize.height
                )
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: viewModel.canvasSize.width * scale,
                    height: viewModel.canvasSize.height * scale,
                    alignment: .topLeading
                )
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value, 0.3), 3.0)
                    }
                    .onEnded { value in
                        lastScale = min(max(lastScale * value, 0.3), 3.0)
                    }
            )
        }
    }

    // MARK: - Info Header

    private var infoHeader: some View {
        HStack(spacing: theme.spacingMD) {
            Label(
                "\(viewModel.sessions.count) session\(viewModel.sessions.count == 1 ? "" : "s")",
                systemImage: "arrow.triangle.branch"
            )
            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)

            if let root = viewModel.rootSession {
                Label(root.displayName, systemImage: "star")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            if viewModel.isComparisonMode {
                Label(
                    viewModel.comparisonSelections.count == 2
                        ? "Path highlighted"
                        : "Select \(2 - viewModel.comparisonSelections.count) more",
                    systemImage: "checkmark.circle"
                )
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.warning)
            }

            Spacer()

            Text(String(format: "%.0f%%", scale * 100))
                .font(
                    .system(size: theme.fontCaption, design: theme.fontDesign)
                    .monospacedDigit()
                )
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .background(theme.bgSecondary)
    }

    // MARK: - Grid Background

    private var gridBackground: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 30
            let dotRadius: CGFloat = 1.0
            var dotPath = Path()

            var x: CGFloat = gridSize
            while x < size.width {
                var y: CGFloat = gridSize
                while y < size.height {
                    dotPath.addEllipse(
                        in: CGRect(
                            x: x - dotRadius, y: y - dotRadius,
                            width: dotRadius * 2, height: dotRadius * 2
                        )
                    )
                    y += gridSize
                }
                x += gridSize
            }
            context.fill(dotPath, with: .color(theme.textTertiary.opacity(0.25)))
        }
    }

    // MARK: - Connection Lines

    private var connectionLines: some View {
        Canvas { [sessions = viewModel.sessions,
                  positions = viewModel.nodePositions,
                  comparisonPath = viewModel.comparisonPath,
                  comparisonSelections = viewModel.comparisonSelections,
                  isComparisonMode = viewModel.isComparisonMode,
                  glassBorder = theme.glassBorder,
                  warning = theme.warning,
                  nodeHeight = nodeHeight] context, _ in
            for session in sessions {
                guard
                    let parentId = session.forkedFrom,
                    let fromPos = positions[parentId],
                    let toPos = positions[session.id]
                else { continue }

                let fromPoint = CGPoint(x: fromPos.x, y: fromPos.y + nodeHeight / 2)
                let toPoint  = CGPoint(x: toPos.x,   y: toPos.y   - nodeHeight / 2)
                let midY = (fromPoint.y + toPoint.y) / 2

                var path = Path()
                path.move(to: fromPoint)
                path.addCurve(
                    to: toPoint,
                    control1: CGPoint(x: fromPoint.x, y: midY),
                    control2: CGPoint(x: toPoint.x, y: midY)
                )

                let isHighlighted = isComparisonMode
                    && comparisonSelections.count == 2
                    && (comparisonPath.contains(session.id) || comparisonPath.contains(parentId))

                context.stroke(
                    path,
                    with: .color(isHighlighted ? warning : glassBorder),
                    style: StrokeStyle(
                        lineWidth: isHighlighted ? 2.5 : 1.5,
                        lineCap: .round
                    )
                )
            }
        }
    }

    // MARK: - Node Card

    @ViewBuilder
    private func nodeCard(for session: ChatSession) -> some View {
        let isSelected      = viewModel.comparisonSelections.contains(session.id)
        let isOnPath        = viewModel.isComparisonMode
            && viewModel.comparisonSelections.count == 2
            && viewModel.comparisonPath.contains(session.id)
        let isRoot          = session.id == viewModel.rootSession?.id
        let statusColor     = nodeStatusColor(for: session.status)

        VStack(alignment: .leading, spacing: 4) {
            // Name row
            HStack(spacing: 4) {
                if isRoot {
                    Image(systemName: "star.fill")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.accent)
                }
                Text(session.displayName)
                    .font(
                        .system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign)
                    )
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
            }

            // Status row
            HStack(spacing: 4) {
                Image(systemName: nodeStatusIcon(for: session.status))
                    // ACC-007: Use 11pt minimum for Dynamic Type compliance
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(statusColor)
                Text(session.status.rawValue.capitalized)
                    // ACC-007: Use 11pt minimum for Dynamic Type compliance
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(statusColor)
            }

            Spacer(minLength: 0)

            // Bottom row: message count + date
            HStack {
                Label("\(session.messageCount)", systemImage: "message")
                    // ACC-007: Use 11pt minimum for Dynamic Type compliance
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                Spacer()

                Text(session.createdAt, style: .date)
                    // ACC-007: Use 11pt minimum for Dynamic Type compliance
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingSM)
        .frame(width: nodeWidth, height: nodeHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .fill(
                    isSelected ? statusColor.opacity(0.15) :
                    isOnPath   ? theme.warning.opacity(0.08) :
                    theme.glassBackground
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(
                    isSelected ? statusColor :
                    isOnPath   ? theme.warning :
                    statusColor.opacity(0.4),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(
            color: isSelected ? statusColor.opacity(0.3) : .clear,
            radius: 6
        )
        .onTapGesture {
            if viewModel.isComparisonMode {
                viewModel.toggleComparisonSelection(id: session.id)
            } else {
                onNavigate(session)
            }
        }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Status Helpers

    private func nodeStatusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active:    return theme.accent
        case .completed: return theme.success
        case .error:     return theme.error
        case .cancelled: return theme.warning
        }
    }

    private func nodeStatusIcon(for status: SessionStatus) -> String {
        switch status {
        case .active:    return "circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .error:     return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }
}
