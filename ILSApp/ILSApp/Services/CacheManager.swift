import Foundation

@MainActor
class CacheManager: ObservableObject {
    static let shared = CacheManager()

    @Published var isOffline: Bool = false
    @Published var cacheSize: String = "0 KB"
    @Published var lastSyncDate: Date?

    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let docs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = docs.appendingPathComponent("ils-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        updateCacheSize()
    }

    func cache<T: Encodable>(_ data: T, forKey key: String) {
        let url = cacheDirectory.appendingPathComponent("\(key).json")
        if let encoded = try? encoder.encode(data) {
            try? encoded.write(to: url)
            lastSyncDate = Date()
            updateCacheSize()
        }
    }

    func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        let url = cacheDirectory.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        updateCacheSize()
    }

    func updateCacheSize() {
        let size = directorySize(url: cacheDirectory)
        if size < 1024 {
            cacheSize = "\(size) B"
        } else if size < 1024 * 1024 {
            cacheSize = "\(size / 1024) KB"
        } else {
            cacheSize = String(format: "%.1f MB", Double(size) / 1024.0 / 1024.0)
        }
    }

    private func directorySize(url: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += size
            }
        }
        return total
    }
}
