import XCTest

/// Measures CPU usage and wall-clock response time for search query interactions.
/// Uses XCTCPUMetric for CPU time and XCTClockMetric for wall-clock elapsed time
/// from the moment a search term is typed until results are visible.
///
/// The manuallyStop option ensures only the active search query is measured,
/// not the teardown that clears the search field and dismisses the keyboard.
final class SearchPerformanceTests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = ["BACKEND_URL": "http://localhost:9999"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Search Performance

    /// Measures CPU usage and wall-clock time for a search query against the sessions list.
    /// Activates the search field, types a query, and waits for results to populate.
    /// Uses manuallyStop so only the active query window is captured; the field
    /// clear and keyboard dismiss occur outside the measurement window.
    func testSearchQueryResponseTime() throws {
        // Wait for the sessions list to appear
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        // Locate the search field — try a search bar first, then a search field
        let searchBar = app.searchFields.firstMatch

        guard searchBar.waitForExistence(timeout: 10) else {
            XCTFail("Search field did not appear within 10 seconds")
            return
        }

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]

        measure(
            metrics: [
                XCTCPUMetric(application: app),
                XCTClockMetric()
            ],
            options: options
        ) {
            // Activate and type a representative query
            searchBar.tap()
            searchBar.typeText("session")

            // Wait for results to settle (first result cell or no-results label)
            let resultsAppeared = sessionsList.cells.firstMatch.waitForExistence(timeout: 5)
                || app.staticTexts["No Results"].waitForExistence(timeout: 5)
            _ = resultsAppeared
            stopMeasuring()

            // Clear the search field and dismiss keyboard outside the measurement window
            searchBar.buttons["Clear text"].tap()
            app.keyboards.buttons["return"].tap()
        }
    }

    /// Measures CPU usage and wall-clock time for each keystroke during incremental search.
    /// Simulates a user typing a multi-character query character-by-character and measures
    /// the cumulative cost of filtering results on each input change.
    func testIncrementalSearchResponseTime() throws {
        // Wait for the sessions list to appear
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        let searchBar = app.searchFields.firstMatch

        guard searchBar.waitForExistence(timeout: 10) else {
            XCTFail("Search field did not appear within 10 seconds")
            return
        }

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]

        measure(
            metrics: [
                XCTCPUMetric(application: app),
                XCTClockMetric()
            ],
            options: options
        ) {
            searchBar.tap()

            // Type each character individually to exercise incremental filtering
            for character in "claude" {
                searchBar.typeText(String(character))
            }

            // Wait for the final filtered result set to stabilise
            _ = sessionsList.cells.firstMatch.waitForExistence(timeout: 5)
                || app.staticTexts["No Results"].waitForExistence(timeout: 5)

            stopMeasuring()

            // Reset outside the measurement window
            searchBar.buttons["Clear text"].tap()
            app.keyboards.buttons["return"].tap()
        }
    }
}
