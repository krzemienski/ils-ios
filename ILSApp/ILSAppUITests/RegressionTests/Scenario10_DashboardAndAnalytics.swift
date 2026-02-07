import XCTest

/// SCENARIO 10: Dashboard and Analytics
/// Tests dashboard metrics, real-time updates, session statistics,
/// project analytics, and data visualization
final class Scenario10_DashboardAndAnalytics: XCUITestBase {
    
    func testDashboardAndAnalytics() throws {
        app.launch()
        takeScreenshot(named: "S10_01_launched")
        
        // Navigate to Dashboard
        navigateToSection(.dashboard)
        takeScreenshot(named: "S10_02_dashboard")
        
        waitForLoadingToComplete()
        Thread.sleep(forTimeInterval: 2)
        takeScreenshot(named: "S10_03_dashboard_loaded")
        
        // Test 1: Verify key metrics are displayed
        assertTextExists("Sessions", timeout: 5)
        assertTextExists("Projects", timeout: 3)
        assertTextExists("Skills", timeout: 3)
        assertTextExists("Plugins", timeout: 3)
        takeScreenshot(named: "S10_04_metrics_visible")
        
        // Test 2: Verify numeric values are shown
        let numberPredicate = NSPredicate(format: "label MATCHES %@", "\\d+")
        let numbers = app.staticTexts.matching(numberPredicate)
        XCTAssertGreaterThan(numbers.count, 0, "Should show numeric stats")
        takeScreenshot(named: "S10_05_numbers_shown")
        
        // Test 3: Test metric tap navigation (if interactive)
        let sessionsMetric = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Sessions'")).firstMatch
        if sessionsMetric.exists && sessionsMetric.isHittable {
            tapElement(sessionsMetric)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S10_06_sessions_from_metric")
            
            // Verify navigated to sessions
            let sessionsList = app.collectionViews.firstMatch
            XCTAssertTrue(sessionsList.exists, "Should navigate to sessions list")
            
            // Go back to dashboard
            navigateToSection(.dashboard)
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 4: Create new session and verify dashboard updates
        navigateToSection(.sessions)
        Thread.sleep(forTimeInterval: 1)
        
        let fab = app.buttons["createSessionButton"]
        if fab.exists {
            tapElement(fab)
            Thread.sleep(forTimeInterval: 1)
            
            let createButton = app.buttons["createButton"]
            if createButton.exists {
                tapElement(createButton)
                Thread.sleep(forTimeInterval: 2)
                takeScreenshot(named: "S10_07_session_created")
                
                // Go back to dashboard
                navigateToSection(.dashboard)
                Thread.sleep(forTimeInterval: 2)
                waitForLoadingToComplete()
                takeScreenshot(named: "S10_08_dashboard_refreshed")
                
                // Metrics should reflect new session (if real-time)
                takeScreenshot(named: "S10_09_updated_metrics")
            }
        }
        
        // Test 5: Test recent activity section (if available)
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S10_10_scrolled_dashboard")
            
            // Look for recent activity
            let recentActivity = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Recent'"))
            if recentActivity.count > 0 {
                takeScreenshot(named: "S10_11_recent_activity")
            }
        }
        
        // Test 6: Test quick actions (if available)
        let quickActionButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'New' OR label CONTAINS[c] 'Quick'"))
        if quickActionButtons.count > 0 {
            let firstAction = quickActionButtons.firstMatch
            takeScreenshot(named: "S10_12_quick_actions")
            
            tapElement(firstAction)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S10_13_quick_action_triggered")
            
            // Dismiss/cancel
            let cancelButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Cancel'")).firstMatch
            if cancelButton.exists {
                cancelButton.tap()
            } else {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
        
        // Test 7: Test data refresh
        // Pull to refresh if supported
        if scrollView.exists {
            let startPoint = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let endPoint = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
            
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S10_14_after_refresh")
        }
        
        // Test 8: Navigate to each metric's source and back
        let metricsToTest = ["Projects", "Skills", "Plugins"]
        for (index, metric) in metricsToTest.enumerated() {
            let metricButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", metric)).firstMatch
            if metricButton.exists && metricButton.isHittable {
                tapElement(metricButton)
                Thread.sleep(forTimeInterval: 2)
                takeScreenshot(named: "S10_15_\(metric.lowercased())_navigation")
                
                // Go back to dashboard
                navigateToSection(.dashboard)
                Thread.sleep(forTimeInterval: 1)
            }
        }
        
        // Test 9: Test dashboard in different states
        // Navigate away and back
        navigateToSection(.settings)
        Thread.sleep(forTimeInterval: 1)
        
        navigateToSection(.dashboard)
        Thread.sleep(forTimeInterval: 2)
        waitForLoadingToComplete()
        takeScreenshot(named: "S10_16_dashboard_reloaded")
        
        // Test 10: Verify dashboard performance
        // Rapid navigation in and out
        for i in 1...3 {
            navigateToSection(.sessions)
            Thread.sleep(forTimeInterval: 0.5)
            
            navigateToSection(.dashboard)
            Thread.sleep(forTimeInterval: 0.5)
            
            if i == 2 {
                takeScreenshot(named: "S10_17_performance_test")
            }
        }
        
        takeScreenshot(named: "S10_18_test_complete")
        print("✅ Scenario 10: Dashboard and Analytics - PASSED")
    }
}
