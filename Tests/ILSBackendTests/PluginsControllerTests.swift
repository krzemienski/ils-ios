import XCTest
@testable import ILSBackend
@testable import ILSShared

final class PluginsControllerTests: XCTestCase {

    // Test 1: PluginInfo encodes all fields correctly
    func testPluginInfoEncodingIncludesAllFields() throws {
        let plugin = PluginInfo(
            name: "test-plugin",
            description: "A test plugin",
            author: "Test Author",
            installCount: 500,
            rating: 4.7,
            reviewCount: 25,
            tags: ["test", "sample"],
            version: "2.1.0",
            screenshots: ["https://example.com/screenshot1.png"]
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(plugin)

        // Decode back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PluginInfo.self, from: data)

        // Verify all fields preserved
        XCTAssertEqual(decoded.name, "test-plugin")
        XCTAssertEqual(decoded.description, "A test plugin")
        XCTAssertEqual(decoded.author, "Test Author")
        XCTAssertEqual(decoded.installCount, 500)
        XCTAssertEqual(decoded.rating, 4.7)
        XCTAssertEqual(decoded.reviewCount, 25)
        XCTAssertEqual(decoded.tags, ["test", "sample"])
        XCTAssertEqual(decoded.version, "2.1.0")
        XCTAssertEqual(decoded.screenshots, ["https://example.com/screenshot1.png"])

        // Verify JSON contains all keys
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["name"])
        XCTAssertNotNil(json["description"])
        XCTAssertNotNil(json["author"])
        XCTAssertNotNil(json["installCount"])
        XCTAssertNotNil(json["rating"])
        XCTAssertNotNil(json["reviewCount"])
        XCTAssertNotNil(json["tags"])
        XCTAssertNotNil(json["version"])
        XCTAssertNotNil(json["screenshots"])
    }

    // Test 2: Search filter works correctly
    func testSearchFilterMatchesNameAndDescription() throws {
        let plugins = [
            PluginInfo(name: "github", description: "GitHub integration"),
            PluginInfo(name: "jira", description: "Jira integration"),
            PluginInfo(name: "linear", description: "Linear integration")
        ]

        let controller = PluginsController()

        // Test search by name (case-insensitive)
        let githubResults = controller.filterPlugins(plugins, search: "github", tag: nil)
        XCTAssertEqual(githubResults.count, 1)
        XCTAssertEqual(githubResults[0].name, "github")

        // Test search by description keyword
        let integrationResults = controller.filterPlugins(plugins, search: "integration", tag: nil)
        XCTAssertEqual(integrationResults.count, 3)

        // Test no match
        let noResults = controller.filterPlugins(plugins, search: "nonexistent", tag: nil)
        XCTAssertEqual(noResults.count, 0)

        // Test case-insensitive search
        let caseInsensitiveResults = controller.filterPlugins(plugins, search: "GITHUB", tag: nil)
        XCTAssertEqual(caseInsensitiveResults.count, 1)
        XCTAssertEqual(caseInsensitiveResults[0].name, "github")
    }

    // Test 3: Tag filter works correctly
    func testTagFilterMatchesPluginTags() throws {
        let plugins = [
            PluginInfo(name: "github", description: "GitHub", tags: ["version-control", "popular"]),
            PluginInfo(name: "jira", description: "Jira", tags: ["project-management"]),
            PluginInfo(name: "linear", description: "Linear", tags: ["project-management", "issue-tracking"])
        ]

        let controller = PluginsController()

        // Test filter by single tag
        let versionControlResults = controller.filterPlugins(plugins, search: nil, tag: "version-control")
        XCTAssertEqual(versionControlResults.count, 1)
        XCTAssertEqual(versionControlResults[0].name, "github")

        // Test filter by common tag
        let projectMgmtResults = controller.filterPlugins(plugins, search: nil, tag: "project-management")
        XCTAssertEqual(projectMgmtResults.count, 2)

        // Test no match
        let noResults = controller.filterPlugins(plugins, search: nil, tag: "nonexistent-tag")
        XCTAssertEqual(noResults.count, 0)

        // Test plugin with no tags
        let pluginNoTags = [PluginInfo(name: "test", description: "Test plugin")]
        let noTagResults = controller.filterPlugins(pluginNoTags, search: nil, tag: "any-tag")
        XCTAssertEqual(noTagResults.count, 0)
    }

    // Test 4: Version comparison works correctly
    func testVersionComparison() throws {
        let controller = PluginsController()

        // Test newer version
        XCTAssertTrue(controller.compareVersions(installed: "1.0.0", latest: "2.0.0"))
        XCTAssertTrue(controller.compareVersions(installed: "1.2.0", latest: "1.3.0"))
        XCTAssertTrue(controller.compareVersions(installed: "1.2.3", latest: "1.2.4"))

        // Test equal versions
        XCTAssertFalse(controller.compareVersions(installed: "1.0.0", latest: "1.0.0"))

        // Test older version (no update needed)
        XCTAssertFalse(controller.compareVersions(installed: "2.0.0", latest: "1.0.0"))

        // Test major version bump
        XCTAssertTrue(controller.compareVersions(installed: "1.9.9", latest: "2.0.0"))

        // Test minor version bump
        XCTAssertTrue(controller.compareVersions(installed: "1.1.9", latest: "1.2.0"))

        // Test patch version bump
        XCTAssertTrue(controller.compareVersions(installed: "1.2.3", latest: "1.2.4"))
    }

    // Test 5: Combined search and tag filter
    func testCombinedSearchAndTagFilter() throws {
        let plugins = [
            PluginInfo(name: "github", description: "GitHub integration", tags: ["version-control", "collaboration"]),
            PluginInfo(name: "gitlab", description: "GitLab integration", tags: ["version-control", "collaboration"]),
            PluginInfo(name: "jira", description: "Jira integration", tags: ["project-management"])
        ]

        let controller = PluginsController()

        // Test search + tag filter (should match both)
        let results = controller.filterPlugins(plugins, search: "git", tag: "version-control")
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.name == "github" })
        XCTAssertTrue(results.contains { $0.name == "gitlab" })

        // Test search + tag filter with no overlap
        let noResults = controller.filterPlugins(plugins, search: "jira", tag: "version-control")
        XCTAssertEqual(noResults.count, 0)
    }
}
