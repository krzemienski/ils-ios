import Foundation
import Observation
import CoreGraphics
import ILSShared

/// View model for the session fork tree visualization.
///
/// Fetches the complete fork lineage for a session family from the backend,
/// computes a layered tree layout for SwiftUI Canvas rendering, and manages
/// branch comparison selection state.
///
/// ## Topics
/// ### Properties
/// - ``sessions`` - All sessions in the fork tree family
/// - ``nodePositions`` - Computed canvas positions keyed by session ID
/// - ``canvasSize`` - Total canvas bounds for the rendered tree
/// - ``isComparisonMode`` - Whether branch comparison selection is active
///
/// ### Methods
/// - ``loadForkTree(sessionId:)`` - Fetch fork tree from API and compute layout
/// - ``toggleComparisonSelection(id:)`` - Select/deselect a node for branch comparison
@Observable
@MainActor
class SessionForkTreeViewModel: BaseViewModel {
    // MARK: - Layout Constants

    private enum Layout {
        static let nodeWidth: CGFloat = 200
        static let nodeHeight: CGFloat = 100
        static let nodeHorizontalSpacing: CGFloat = 240
        static let nodeVerticalSpacing: CGFloat = 160
        static let canvasPadding: CGFloat = 40
    }

    // MARK: - Properties

    /// Root session of the fork tree (the ancestor with no forkedFrom).
    var rootSession: ChatSession?

    /// All sessions belonging to this fork family, in tree order.
    var sessions: [ChatSession] = []

    /// Computed canvas positions for each session node, keyed by session ID.
    var nodePositions: [UUID: CGPoint] = [:]

    /// The two session IDs selected for branch comparison (at most 2).
    var comparisonSelections: [UUID] = []

    /// Whether branch comparison mode is active.
    var isComparisonMode: Bool = false

    // MARK: - API

    /// Fetch the fork tree for the given session and compute the canvas layout.
    ///
    /// - Parameter sessionId: The ID of any session in the fork family.
    func loadForkTree(sessionId: UUID) async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<SessionForkTreeResponse> = try await client.get(
                "/sessions/\(sessionId.uuidString.lowercased())/fork-tree"
            )
            if let data = response.data {
                sessions = data.sessions
                rootSession = data.sessions.first { $0.id == data.rootId }
                computeLayout(rootId: data.rootId)
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load fork tree for \(sessionId): \(error.localizedDescription)",
                category: "sessions"
            )
        }

        isLoading = false
    }

    // MARK: - Layout Computation

    /// Compute canvas positions for each node using a layered (Reingold-Tilford-style) BFS layout.
    ///
    /// Sessions are grouped by depth from the root. Within each depth level, nodes are
    /// distributed horizontally with equal spacing and centered relative to the widest level.
    ///
    /// - Parameter rootId: The ID of the root session (depth 0).
    private func computeLayout(rootId: UUID) {
        guard !sessions.isEmpty else {
            nodePositions = [:]
            return
        }

        // Build parent→children map
        var childrenMap: [UUID: [UUID]] = [:]
        for session in sessions {
            if let parentId = session.forkedFrom {
                childrenMap[parentId, default: []].append(session.id)
            }
        }

        // BFS from root to assign depths
        var depthMap: [UUID: Int] = [:]
        var queue: [(id: UUID, depth: Int)] = [(rootId, 0)]
        depthMap[rootId] = 0

        while !queue.isEmpty {
            let (currentId, depth) = queue.removeFirst()
            let children = childrenMap[currentId] ?? []
            for childId in children {
                if depthMap[childId] == nil {
                    depthMap[childId] = depth + 1
                    queue.append((childId, depth + 1))
                }
            }
        }

        // Group session IDs by depth level, preserving session order within each level
        var levelGroups: [Int: [UUID]] = [:]
        for session in sessions {
            let depth = depthMap[session.id] ?? 0
            levelGroups[depth, default: []].append(session.id)
        }

        let maxDepth = levelGroups.keys.max() ?? 0
        let maxLevelWidth = levelGroups.values.map { $0.count }.max() ?? 1

        // Total canvas width driven by the widest level
        let totalWidth = CGFloat(maxLevelWidth) * Layout.nodeHorizontalSpacing

        var positions: [UUID: CGPoint] = [:]

        for depth in 0...maxDepth {
            guard let ids = levelGroups[depth] else { continue }
            let levelCount = CGFloat(ids.count)
            let levelTotalWidth = levelCount * Layout.nodeHorizontalSpacing

            // Center this level horizontally within the canvas
            let xOffset = (totalWidth - levelTotalWidth) / 2 + Layout.canvasPadding

            for (index, id) in ids.enumerated() {
                let x = xOffset + CGFloat(index) * Layout.nodeHorizontalSpacing + Layout.nodeWidth / 2
                let y = Layout.canvasPadding + CGFloat(depth) * Layout.nodeVerticalSpacing + Layout.nodeHeight / 2
                positions[id] = CGPoint(x: x, y: y)
            }
        }

        nodePositions = positions
    }

    // MARK: - Canvas Geometry

    /// Total canvas size needed to render all nodes with padding.
    var canvasSize: CGSize {
        guard !nodePositions.isEmpty else {
            return CGSize(width: 400, height: 300)
        }
        let maxX = (nodePositions.values.map(\.x).max() ?? 0) + Layout.nodeWidth / 2 + Layout.canvasPadding
        let maxY = (nodePositions.values.map(\.y).max() ?? 0) + Layout.nodeHeight / 2 + Layout.canvasPadding
        return CGSize(width: maxX, height: maxY)
    }

    // MARK: - Branch Comparison

    /// Toggle selection of a node for branch comparison.
    ///
    /// Only two nodes may be selected at once. Selecting a node that is already
    /// selected deselects it. Selecting a third node replaces the oldest selection.
    ///
    /// - Parameter id: The session ID to toggle.
    func toggleComparisonSelection(id: UUID) {
        if let existingIndex = comparisonSelections.firstIndex(of: id) {
            comparisonSelections.remove(at: existingIndex)
        } else if comparisonSelections.count >= 2 {
            // Replace the first (oldest) selection
            comparisonSelections.removeFirst()
            comparisonSelections.append(id)
        } else {
            comparisonSelections.append(id)
        }
    }

    /// The set of session IDs forming the path between the two selected comparison nodes.
    ///
    /// Returns the union of the ancestor paths from each selected node up to their
    /// lowest common ancestor (LCA), forming the divergence path for comparison.
    var comparisonPath: Set<UUID> {
        guard comparisonSelections.count == 2 else { return [] }
        let id1 = comparisonSelections[0]
        let id2 = comparisonSelections[1]

        // Build a parent lookup for fast traversal
        var parentMap: [UUID: UUID] = [:]
        for session in sessions {
            if let parent = session.forkedFrom {
                parentMap[session.id] = parent
            }
        }

        // Collect ancestor chain for a given node (inclusive)
        func ancestors(of id: UUID) -> [UUID] {
            var chain: [UUID] = []
            var current: UUID? = id
            while let node = current {
                chain.append(node)
                current = parentMap[node]
            }
            return chain
        }

        let chain1 = ancestors(of: id1)
        let chain2 = ancestors(of: id2)

        let ancestors1 = Set(chain1)
        let ancestors2 = Set(chain2)

        // Find the lowest common ancestor
        guard let lca = chain1.first(where: { ancestors2.contains($0) }) else {
            // No common ancestor — return union of both chains
            return ancestors1.union(ancestors2)
        }

        // Collect path from id1 up to LCA
        var path1: Set<UUID> = []
        for node in chain1 {
            path1.insert(node)
            if node == lca { break }
        }

        // Collect path from id2 up to LCA
        var path2: Set<UUID> = []
        for node in chain2 {
            path2.insert(node)
            if node == lca { break }
        }

        return path1.union(path2)
    }
}
