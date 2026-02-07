import XCTest

/// SCENARIO 8: Settings Configuration
/// Tests server configuration, SSH connections, cloud sync,
/// notification preferences, and appearance settings
final class Scenario08_SettingsConfiguration: XCUITestBase {
    
    func testSettingsConfiguration() throws {
        app.launch()
        takeScreenshot(named: "S08_01_launched")
        
        // Navigate to Settings
        navigateToSection(.settings)
        takeScreenshot(named: "S08_02_settings")
        
        let settingsList = app.collectionViews.firstMatch
        waitForElement(settingsList, timeout: 5)
        takeScreenshot(named: "S08_03_settings_loaded")
        
        // Test 1: Server Configuration
        let serverConfigButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Server Configuration'")).firstMatch
        if serverConfigButton.exists {
            tapElement(serverConfigButton)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S08_04_server_config")
            
            // Verify server URL field exists
            let urlField = app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'localhost'")).firstMatch
            XCTAssertTrue(urlField.exists, "Server URL field should exist")
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 2: SSH Connections
        let sshButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'SSH Connections'")).firstMatch
        if sshButton.exists {
            tapElement(sshButton)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S08_05_ssh_connections")
            
            // Add new SSH connection
            let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '+'")).firstMatch
            if addButton.exists {
                tapElement(addButton)
                Thread.sleep(forTimeInterval: 2)
                takeScreenshot(named: "S08_06_ssh_form")
                
                // Fill in SSH details
                let hostField = app.textFields["hostField"]
                if hostField.exists {
                    typeText("test.example.com", into: hostField)
                }
                
                let usernameField = app.textFields["usernameField"]
                if usernameField.exists {
                    typeText("testuser", into: usernameField)
                }
                
                let portField = app.textFields["portField"]
                if portField.exists {
                    clearAndType("2222", into: portField)
                }
                
                takeScreenshot(named: "S08_07_ssh_form_filled")
                
                // Save connection
                let saveButton = app.buttons["saveButton"]
                if saveButton.exists {
                    tapElement(saveButton)
                    Thread.sleep(forTimeInterval: 2)
                    takeScreenshot(named: "S08_08_ssh_saved")
                }
            }
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 3: Cloud Sync
        let cloudSyncButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Cloud Sync'")).firstMatch
        if cloudSyncButton.exists {
            tapElement(cloudSyncButton)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S08_09_cloud_sync")
            
            // Test toggle
            let syncToggle = app.switches.firstMatch
            if syncToggle.exists {
                syncToggle.tap()
                Thread.sleep(forTimeInterval: 1)
                takeScreenshot(named: "S08_10_sync_toggled")
                
                // Toggle back
                syncToggle.tap()
                Thread.sleep(forTimeInterval: 1)
            }
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 4: Notification Preferences
        let notificationsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Notification'")).firstMatch
        if notificationsButton.exists {
            tapElement(notificationsButton)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S08_11_notifications")
            
            // Test notification toggles
            let toggles = app.switches
            if toggles.count > 0 {
                let firstToggle = toggles.firstMatch
                firstToggle.tap()
                Thread.sleep(forTimeInterval: 1)
                takeScreenshot(named: "S08_12_notification_toggled")
                
                // Toggle back
                firstToggle.tap()
                Thread.sleep(forTimeInterval: 1)
            }
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 5: Appearance settings
        let appearanceButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Appearance'")).firstMatch
        if appearanceButton.exists {
            tapElement(appearanceButton)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S08_13_appearance")
            
            // Test theme selection (should be dark mode enforced)
            assertTextExists("Dark", timeout: 3)
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 6: Scroll through settings
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            takeScreenshot(named: "S08_14_scrolled")
            
            scrollView.swipeDown()
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 7: About/Version info (if available)
        let aboutButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'About'")).firstMatch
        if aboutButton.exists {
            tapElement(aboutButton)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S08_15_about")
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
        }
        
        takeScreenshot(named: "S08_16_test_complete")
        print("✅ Scenario 8: Settings Configuration - PASSED")
    }
}
