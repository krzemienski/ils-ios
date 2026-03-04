import CloudKit
import Foundation
import Observation

// MARK: - QuickReplyTemplateManager

/// Manages quick reply templates with local persistence and cross-device CloudKit sync.
///
/// Custom templates are persisted locally as JSON in UserDefaults and synced to the
/// CloudKit private database. Conflict resolution uses last-write-wins semantics via
/// an internal modification-date dictionary. Built-in templates (from
/// `QuickReplyTemplate.builtIns`) are always loaded fresh and are never written to
/// CloudKit.
///
/// Uses @Observable for zero-overhead SwiftUI integration.
@MainActor
@Observable
final class QuickReplyTemplateManager {
    static let shared = QuickReplyTemplateManager()

    // MARK: - Observable State

    private(set) var customTemplates: [QuickReplyTemplate] = []
    private(set) var isSyncing = false

    // MARK: - Constants

    private enum StorageKey {
        static let customTemplates = "quick_reply_templates"
        static let modifiedDates = "quick_reply_template_modified_dates"
        static let pinnedBuiltInNames = "quick_reply_pinned_builtin_names"
    }

    private enum CloudKitConfig {
        static let containerIdentifier = "iCloud.com.ils.app"
        static let recordType = "QuickReplyTemplate"
    }

    private enum RecordField {
        static let name = "name"
        static let content = "content"
        static let category = "category"
        static let variables = "variables"
        static let usageStats = "usageStats"
        static let projectOverrides = "projectOverrides"
        static let isFavorite = "isFavorite"
        static let createdAt = "createdAt"
        static let modifiedAt = "modifiedAt"
        static let tags = "tags"
    }

    // MARK: - Private State

    private var database: CKDatabase {
        CKContainer(identifier: CloudKitConfig.containerIdentifier).privateCloudDatabase
    }

    /// Modification dates keyed by template UUID string for last-write-wins merge.
    private var modifiedDates: [String: Date] = [:]

    /// Names of built-in templates that have been pinned by the user.
    private var pinnedBuiltInNames: Set<String> = []

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Init

    private init() {
        customTemplates = loadCustomTemplatesFromLocal()
        modifiedDates = loadModifiedDatesFromLocal()
        pinnedBuiltInNames = loadPinnedBuiltInNamesFromLocal()
    }

    // MARK: - Computed Properties

    /// All templates: built-ins (with pinned state applied) followed by custom templates.
    var allTemplates: [QuickReplyTemplate] {
        let builtIns = QuickReplyTemplate.builtIns.map { template in
            var t = template
            t.isFavorite = pinnedBuiltInNames.contains(t.name)
            return t
        }
        return builtIns + customTemplates
    }

    // MARK: - Public API

    /// Returns all templates optionally filtered by category.
    ///
    /// Pass `nil` for `category` to return all templates across all categories.
    func templates(for category: QuickReplyCategory? = nil) -> [QuickReplyTemplate] {
        guard let category else { return allTemplates }
        return allTemplates.filter { $0.category == category }
    }

    /// Returns pinned templates (built-ins first, then custom), sorted by name.
    func pinnedTemplates() -> [QuickReplyTemplate] {
        allTemplates.filter(\.isFavorite)
    }

    /// Returns the most-used custom templates sorted by usage count descending.
    func mostUsedTemplates(limit: Int = 5) -> [QuickReplyTemplate] {
        Array(
            customTemplates
                .sorted { $0.usageStats.useCount > $1.usageStats.useCount }
                .prefix(limit)
        )
    }

    /// Adds a new custom template and syncs it to CloudKit.
    ///
    /// No-ops silently for built-in templates.
    func addTemplate(_ template: QuickReplyTemplate) async {
        guard !template.isBuiltIn else { return }

        customTemplates.append(template)
        modifiedDates[template.id.uuidString] = Date()
        saveCustomTemplatesToLocal()
        saveModifiedDatesToLocal()
        await saveToCloud(template)

        AppLogger.shared.info(
            "Quick reply template '\(template.name)' added",
            category: "quickReply"
        )
    }

    /// Updates an existing custom template and syncs the change to CloudKit.
    ///
    /// No-ops silently for built-in templates or unknown IDs.
    func updateTemplate(_ template: QuickReplyTemplate) async {
        guard
            !template.isBuiltIn,
            let index = customTemplates.firstIndex(where: { $0.id == template.id })
        else { return }

        customTemplates[index] = template
        modifiedDates[template.id.uuidString] = Date()
        saveCustomTemplatesToLocal()
        saveModifiedDatesToLocal()
        await saveToCloud(template)

        AppLogger.shared.info(
            "Quick reply template '\(template.name)' updated",
            category: "quickReply"
        )
    }

    /// Deletes a custom template and removes it from CloudKit.
    ///
    /// No-ops silently for built-in templates or unknown IDs.
    func deleteTemplate(id: UUID) async {
        guard
            let template = customTemplates.first(where: { $0.id == id }),
            !template.isBuiltIn
        else { return }

        customTemplates.removeAll { $0.id == id }
        modifiedDates.removeValue(forKey: id.uuidString)
        saveCustomTemplatesToLocal()
        saveModifiedDatesToLocal()
        await deleteFromCloud(templateId: id)

        AppLogger.shared.info(
            "Quick reply template \(id) deleted",
            category: "quickReply"
        )
    }

    /// Toggles the pinned (isFavorite) state of a template.
    ///
    /// For built-in templates, the pin state is persisted by template name.
    /// For custom templates, the `isFavorite` flag is toggled and synced to CloudKit.
    func togglePin(id: UUID) async {
        // Check built-ins first (matched by id from the static let array)
        if let builtIn = QuickReplyTemplate.builtIns.first(where: { $0.id == id }) {
            if pinnedBuiltInNames.contains(builtIn.name) {
                pinnedBuiltInNames.remove(builtIn.name)
            } else {
                pinnedBuiltInNames.insert(builtIn.name)
            }
            savePinnedBuiltInNamesToLocal()
            AppLogger.shared.info(
                "Built-in template '\(builtIn.name)' pin toggled",
                category: "quickReply"
            )
            return
        }

        guard let index = customTemplates.firstIndex(where: { $0.id == id }) else { return }
        customTemplates[index].isFavorite.toggle()
        modifiedDates[id.uuidString] = Date()
        saveCustomTemplatesToLocal()
        saveModifiedDatesToLocal()
        await saveToCloud(customTemplates[index])

        AppLogger.shared.info(
            "Custom template \(id) pin toggled",
            category: "quickReply"
        )
    }

    /// Records a usage event for the template with the given ID.
    ///
    /// Usage is tracked for custom templates only; built-in usage is not persisted.
    func recordUsage(id: UUID, projectId: String? = nil) {
        guard let index = customTemplates.firstIndex(where: { $0.id == id }) else { return }
        customTemplates[index].usageStats.recordUse(projectId: projectId)
        saveCustomTemplatesToLocal()
    }

    // MARK: - CloudKit Sync

    /// Pushes all custom templates to CloudKit using a batch save.
    ///
    /// No-ops if a sync is already in progress. Uses `.changedKeys` save policy
    /// so only modified fields are transmitted to reduce bandwidth.
    func syncToCloud() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard !customTemplates.isEmpty else { return }

        let records = customTemplates.map { makeRecord(from: $0) }

        do {
            let (saveResults, _) = try await database.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .changedKeys,
                atomically: false
            )

            let successCount = saveResults.values.filter { result in
                if case .success = result { return true }
                return false
            }.count

            AppLogger.shared.info(
                "Synced \(successCount)/\(records.count) quick reply template(s) to CloudKit",
                category: "quickReply"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to sync quick reply templates to CloudKit: \(error.localizedDescription)",
                category: "quickReply"
            )
        }
    }

    /// Pulls custom templates from CloudKit and merges with local templates.
    ///
    /// Conflict resolution: last-write-wins by stored modification date.
    /// Remote templates with a newer modification date replace the local copy;
    /// local templates without a remote counterpart are preserved.
    func syncFromCloud() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let query = CKQuery(
            recordType: CloudKitConfig.recordType,
            predicate: NSPredicate(value: true)
        )

        do {
            let (matchResults, _) = try await database.records(
                matching: query,
                desiredKeys: nil,
                resultsLimit: CKQueryOperation.maximumResults
            )

            var remoteTemplates: [(QuickReplyTemplate, Date)] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let (template, modDate) = parseRecord(record) {
                        remoteTemplates.append((template, modDate))
                    }
                case .failure(let error):
                    AppLogger.shared.warning(
                        "Failed to parse CloudKit template record: \(error.localizedDescription)",
                        category: "quickReply"
                    )
                }
            }

            mergeRemote(remoteTemplates)

            AppLogger.shared.info(
                "Fetched \(remoteTemplates.count) quick reply template(s) from CloudKit",
                category: "quickReply"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to fetch quick reply templates from CloudKit: \(error.localizedDescription)",
                category: "quickReply"
            )
        }
    }

    // MARK: - CloudKit Helpers

    private func saveToCloud(_ template: QuickReplyTemplate) async {
        let record = makeRecord(from: template)
        do {
            try await database.save(record)
            AppLogger.shared.info(
                "Quick reply template \(template.id) saved to CloudKit",
                category: "quickReply"
            )
        } catch {
            AppLogger.shared.warning(
                "Failed to save quick reply template \(template.id) to CloudKit: \(error.localizedDescription)",
                category: "quickReply"
            )
        }
    }

    private func deleteFromCloud(templateId: UUID) async {
        let recordID = CKRecord.ID(recordName: templateId.uuidString)
        do {
            try await database.deleteRecord(withID: recordID)
            AppLogger.shared.info(
                "Quick reply template \(templateId) deleted from CloudKit",
                category: "quickReply"
            )
        } catch {
            AppLogger.shared.warning(
                "Failed to delete quick reply template \(templateId) from CloudKit: \(error.localizedDescription)",
                category: "quickReply"
            )
        }
    }

    private func makeRecord(from template: QuickReplyTemplate) -> CKRecord {
        let recordID = CKRecord.ID(recordName: template.id.uuidString)
        let record = CKRecord(recordType: CloudKitConfig.recordType, recordID: recordID)
        record[RecordField.name] = template.name as CKRecordValue
        record[RecordField.content] = template.content as CKRecordValue
        record[RecordField.category] = template.category.rawValue as CKRecordValue
        record[RecordField.isFavorite] = (template.isFavorite ? 1 : 0) as CKRecordValue
        record[RecordField.createdAt] = template.createdAt as CKRecordValue
        record[RecordField.modifiedAt] = (modifiedDates[template.id.uuidString] ?? template.createdAt) as CKRecordValue

        if let tagsData = try? encoder.encode(template.tags) {
            record[RecordField.tags] = String(data: tagsData, encoding: .utf8) as CKRecordValue?
        }
        if let variablesData = try? encoder.encode(template.variables) {
            record[RecordField.variables] = String(data: variablesData, encoding: .utf8) as CKRecordValue?
        }
        if let statsData = try? encoder.encode(template.usageStats) {
            record[RecordField.usageStats] = String(data: statsData, encoding: .utf8) as CKRecordValue?
        }
        if let overridesData = try? encoder.encode(template.projectOverrides) {
            record[RecordField.projectOverrides] = String(data: overridesData, encoding: .utf8) as CKRecordValue?
        }
        return record
    }

    private func parseRecord(_ record: CKRecord) -> (QuickReplyTemplate, Date)? {
        guard
            let name = record[RecordField.name] as? String,
            !name.isEmpty,
            let content = record[RecordField.content] as? String,
            let categoryRaw = record[RecordField.category] as? String,
            let category = QuickReplyCategory(rawValue: categoryRaw)
        else { return nil }

        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let isFavorite = (record[RecordField.isFavorite] as? Int ?? 0) != 0
        let createdAt = record[RecordField.createdAt] as? Date ?? Date()
        let modifiedAt = record[RecordField.modifiedAt] as? Date ?? createdAt

        var tags: [String] = []
        if let tagsStr = record[RecordField.tags] as? String,
           let tagsData = tagsStr.data(using: .utf8),
           let decoded = try? decoder.decode([String].self, from: tagsData) {
            tags = decoded
        }

        var variables: [QuickReplyVariable] = []
        if let variablesStr = record[RecordField.variables] as? String,
           let variablesData = variablesStr.data(using: .utf8),
           let decoded = try? decoder.decode([QuickReplyVariable].self, from: variablesData) {
            variables = decoded
        }

        var usageStats = QuickReplyUsageStats()
        if let statsStr = record[RecordField.usageStats] as? String,
           let statsData = statsStr.data(using: .utf8),
           let decoded = try? decoder.decode(QuickReplyUsageStats.self, from: statsData) {
            usageStats = decoded
        }

        var projectOverrides: [QuickReplyProjectOverride] = []
        if let overridesStr = record[RecordField.projectOverrides] as? String,
           let overridesData = overridesStr.data(using: .utf8),
           let decoded = try? decoder.decode([QuickReplyProjectOverride].self, from: overridesData) {
            projectOverrides = decoded
        }

        let template = QuickReplyTemplate(
            id: id,
            name: name,
            content: content,
            category: category,
            variables: variables,
            usageStats: usageStats,
            projectOverrides: projectOverrides,
            isFavorite: isFavorite,
            isBuiltIn: false,
            createdAt: createdAt,
            tags: tags
        )
        return (template, modifiedAt)
    }

    // MARK: - Merge

    /// Merges remote templates into the local set using last-write-wins by modification date.
    private func mergeRemote(_ remoteTemplates: [(QuickReplyTemplate, Date)]) {
        var mergedByID: [UUID: QuickReplyTemplate] = [:]
        var mergedDates: [UUID: Date] = [:]

        for local in customTemplates {
            mergedByID[local.id] = local
            mergedDates[local.id] = modifiedDates[local.id.uuidString] ?? local.createdAt
        }

        for (remote, remoteDate) in remoteTemplates {
            if let existingDate = mergedDates[remote.id] {
                if remoteDate > existingDate {
                    mergedByID[remote.id] = remote
                    mergedDates[remote.id] = remoteDate
                }
            } else {
                mergedByID[remote.id] = remote
                mergedDates[remote.id] = remoteDate
            }
        }

        customTemplates = mergedByID.values.sorted { $0.createdAt > $1.createdAt }
        modifiedDates = Dictionary(uniqueKeysWithValues: mergedDates.map { ($0.key.uuidString, $0.value) })
        saveCustomTemplatesToLocal()
        saveModifiedDatesToLocal()
    }

    // MARK: - Local Persistence

    private func loadCustomTemplatesFromLocal() -> [QuickReplyTemplate] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.customTemplates) else {
            return []
        }
        do {
            return try decoder.decode([QuickReplyTemplate].self, from: data)
        } catch {
            AppLogger.shared.warning(
                "Failed to decode local quick reply templates: \(error.localizedDescription)",
                category: "quickReply"
            )
            return []
        }
    }

    private func saveCustomTemplatesToLocal() {
        do {
            let data = try encoder.encode(customTemplates)
            UserDefaults.standard.set(data, forKey: StorageKey.customTemplates)
        } catch {
            AppLogger.shared.warning(
                "Failed to encode quick reply templates for local storage: \(error.localizedDescription)",
                category: "quickReply"
            )
        }
    }

    private func loadModifiedDatesFromLocal() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.modifiedDates) else {
            return [:]
        }
        do {
            return try decoder.decode([String: Date].self, from: data)
        } catch {
            AppLogger.shared.warning(
                "Failed to decode local quick reply template modified dates: \(error.localizedDescription)",
                category: "quickReply"
            )
            return [:]
        }
    }

    private func saveModifiedDatesToLocal() {
        do {
            let data = try encoder.encode(modifiedDates)
            UserDefaults.standard.set(data, forKey: StorageKey.modifiedDates)
        } catch {
            AppLogger.shared.warning(
                "Failed to encode quick reply template modified dates: \(error.localizedDescription)",
                category: "quickReply"
            )
        }
    }

    private func loadPinnedBuiltInNamesFromLocal() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: StorageKey.pinnedBuiltInNames) ?? []
        return Set(array)
    }

    private func savePinnedBuiltInNamesToLocal() {
        UserDefaults.standard.set(Array(pinnedBuiltInNames), forKey: StorageKey.pinnedBuiltInNames)
    }
}
