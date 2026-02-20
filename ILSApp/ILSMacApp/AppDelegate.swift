import Cocoa
import SwiftUI

/// AppDelegate for macOS-specific app lifecycle and menu bar customization
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running when last window closes (standard macOS behavior)
        return false
    }

    // MARK: - Menu Bar Customization

    private func setupMenuBar() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }

        // Customize the app menu (first menu with app name)
        if let appMenu = mainMenu.items.first?.submenu {
            customizeAppMenu(appMenu)
        }

        // Add File menu
        setupFileMenu(mainMenu)

        // Add Edit menu
        setupEditMenu(mainMenu)

        // Add View menu
        setupViewMenu(mainMenu)

        // Add Window menu
        setupWindowMenu(mainMenu)
    }

    private func setupFileMenu(_ mainMenu: NSMenu) {
        // Check if File menu already exists (SwiftUI may have created one)
        let fileMenu: NSMenu
        if let existingFileMenuItem = mainMenu.items.first(where: { $0.title == "File" }),
           let existingFileMenu = existingFileMenuItem.submenu {
            fileMenu = existingFileMenu
            fileMenu.removeAllItems() // Clear existing items to rebuild
        } else {
            // Create new File menu
            fileMenu = NSMenu(title: "File")
            let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
            fileMenuItem.submenu = fileMenu
            mainMenu.insertItem(fileMenuItem, at: 1) // Insert after App menu
        }

        // New Session (Cmd+N)
        let newSessionItem = NSMenuItem(
            title: "New Session",
            action: #selector(newSession),
            keyEquivalent: "n"
        )
        newSessionItem.target = self
        fileMenu.addItem(newSessionItem)

        // Open Session (Cmd+O)
        let openSessionItem = NSMenuItem(
            title: "Open Session",
            action: #selector(openSession),
            keyEquivalent: "o"
        )
        openSessionItem.target = self
        fileMenu.addItem(openSessionItem)

        fileMenu.addItem(NSMenuItem.separator())

        // Close Window (Cmd+W)
        let closeWindowItem = NSMenuItem(
            title: "Close Window",
            action: #selector(closeWindow),
            keyEquivalent: "w"
        )
        closeWindowItem.target = self
        fileMenu.addItem(closeWindowItem)

        fileMenu.addItem(NSMenuItem.separator())

        // Save (Cmd+S)
        let saveItem = NSMenuItem(
            title: "Save",
            action: #selector(save),
            keyEquivalent: "s"
        )
        saveItem.target = self
        fileMenu.addItem(saveItem)
    }

    private func setupEditMenu(_ mainMenu: NSMenu) {
        // Check if Edit menu already exists (SwiftUI may have created one)
        let editMenu: NSMenu
        if let existingEditMenuItem = mainMenu.items.first(where: { $0.title == "Edit" }),
           let existingEditMenu = existingEditMenuItem.submenu {
            editMenu = existingEditMenu
            editMenu.removeAllItems() // Clear existing items to rebuild
        } else {
            // Create new Edit menu
            editMenu = NSMenu(title: "Edit")
            let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
            editMenuItem.submenu = editMenu
            mainMenu.insertItem(editMenuItem, at: 2) // Insert after File menu
        }

        // Undo (Cmd+Z)
        let undoItem = NSMenuItem(
            title: "Undo",
            action: Selector(("undo:")),
            keyEquivalent: "z"
        )
        editMenu.addItem(undoItem)

        // Redo (Cmd+Shift+Z)
        let redoItem = NSMenuItem(
            title: "Redo",
            action: Selector(("redo:")),
            keyEquivalent: "Z"
        )
        editMenu.addItem(redoItem)

        editMenu.addItem(NSMenuItem.separator())

        // Cut (Cmd+X)
        let cutItem = NSMenuItem(
            title: "Cut",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        editMenu.addItem(cutItem)

        // Copy (Cmd+C)
        let copyItem = NSMenuItem(
            title: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        editMenu.addItem(copyItem)

        // Paste (Cmd+V)
        let pasteItem = NSMenuItem(
            title: "Paste",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        editMenu.addItem(pasteItem)

        editMenu.addItem(NSMenuItem.separator())

        // Select All (Cmd+A)
        let selectAllItem = NSMenuItem(
            title: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        editMenu.addItem(selectAllItem)
    }

    private func setupViewMenu(_ mainMenu: NSMenu) {
        // Check if View menu already exists (SwiftUI may have created one)
        let viewMenu: NSMenu
        if let existingViewMenuItem = mainMenu.items.first(where: { $0.title == "View" }),
           let existingViewMenu = existingViewMenuItem.submenu {
            viewMenu = existingViewMenu
            viewMenu.removeAllItems() // Clear existing items to rebuild
        } else {
            // Create new View menu
            viewMenu = NSMenu(title: "View")
            let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
            viewMenuItem.submenu = viewMenu
            mainMenu.insertItem(viewMenuItem, at: 3) // Insert after Edit menu
        }

        // Toggle Sidebar (Cmd+Ctrl+S)
        let toggleSidebarItem = NSMenuItem(
            title: "Toggle Sidebar",
            action: #selector(toggleSidebar),
            keyEquivalent: "s"
        )
        toggleSidebarItem.keyEquivalentModifierMask = [.command, .control]
        toggleSidebarItem.target = self
        viewMenu.addItem(toggleSidebarItem)

        viewMenu.addItem(NSMenuItem.separator())

        // Show Dashboard (Cmd+1)
        let showDashboardItem = NSMenuItem(
            title: "Show Dashboard",
            action: #selector(showDashboard),
            keyEquivalent: "1"
        )
        showDashboardItem.target = self
        viewMenu.addItem(showDashboardItem)

        // Show Sessions (Cmd+2)
        let showSessionsItem = NSMenuItem(
            title: "Show Sessions",
            action: #selector(showSessions),
            keyEquivalent: "2"
        )
        showSessionsItem.target = self
        viewMenu.addItem(showSessionsItem)

        // Show Projects (Cmd+3)
        let showProjectsItem = NSMenuItem(
            title: "Show Projects",
            action: #selector(showProjects),
            keyEquivalent: "3"
        )
        showProjectsItem.target = self
        viewMenu.addItem(showProjectsItem)

        // Show System (Cmd+4)
        let showSystemItem = NSMenuItem(
            title: "Show System",
            action: #selector(showSystem),
            keyEquivalent: "4"
        )
        showSystemItem.target = self
        viewMenu.addItem(showSystemItem)

        // Show Browser (Cmd+5)
        let showBrowserItem = NSMenuItem(
            title: "Show Browser",
            action: #selector(showBrowser),
            keyEquivalent: "5"
        )
        showBrowserItem.target = self
        viewMenu.addItem(showBrowserItem)

        // Show Settings (Cmd+6)
        let showSettingsItem = NSMenuItem(
            title: "Show Settings",
            action: #selector(showSettings),
            keyEquivalent: "6"
        )
        showSettingsItem.target = self
        viewMenu.addItem(showSettingsItem)
    }

    private func setupWindowMenu(_ mainMenu: NSMenu) {
        // Check if Window menu already exists (SwiftUI may have created one)
        let windowMenu: NSMenu
        if let existingWindowMenuItem = mainMenu.items.first(where: { $0.title == "Window" }),
           let existingWindowMenu = existingWindowMenuItem.submenu {
            windowMenu = existingWindowMenu
            windowMenu.removeAllItems() // Clear existing items to rebuild
        } else {
            // Create new Window menu
            windowMenu = NSMenu(title: "Window")
            let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
            windowMenuItem.submenu = windowMenu
            mainMenu.insertItem(windowMenuItem, at: 4) // Insert after View menu
        }

        // Minimize (Cmd+M)
        let minimizeItem = NSMenuItem(
            title: "Minimize",
            action: #selector(NSWindow.miniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(minimizeItem)

        // Zoom
        let zoomItem = NSMenuItem(
            title: "Zoom",
            action: #selector(NSWindow.zoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(zoomItem)

        windowMenu.addItem(NSMenuItem.separator())

        // Bring All to Front
        let bringAllToFrontItem = NSMenuItem(
            title: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(bringAllToFrontItem)

        // Tell macOS this is the Windows menu (automatically adds window list)
        NSApp.windowsMenu = windowMenu
    }

    private func customizeAppMenu(_ menu: NSMenu) {
        // The app menu already has standard items from SwiftUI:
        // - About ILS
        // - Preferences (Cmd+,)
        // - Services submenu
        // - Hide/Show items
        // - Quit ILS (Cmd+Q)

        // We can add custom items if needed. For now, just ensure the structure is correct.
        // Additional customization will be added in subsequent subtasks (File, Edit, View, Window menus)

        // Example: Add a separator and custom menu item after About
        // let aboutItem = menu.items.first
        // let customItem = NSMenuItem(title: "Custom Action", action: #selector(customAction), keyEquivalent: "")
        // customItem.target = self
        // menu.insertItem(NSMenuItem.separator(), at: 1)
        // menu.insertItem(customItem, at: 2)
    }

    // MARK: - Menu Actions

    @objc private func newSession() {
        // Post notification to create new session
        // This will be handled by the main ContentView or SessionsViewModel
        NotificationCenter.default.post(name: NSNotification.Name("CreateNewSession"), object: nil)
    }

    @objc private func openSession() {
        // Post notification to show session picker
        // This will be handled by the SessionsViewModel to show a picker dialog
        NotificationCenter.default.post(name: NSNotification.Name("OpenSession"), object: nil)
    }

    @objc private func closeWindow() {
        // Close the current key window
        NSApp.keyWindow?.close()
    }

    @objc private func save() {
        // Post notification to save current session
        // This will be handled by the ChatViewModel to export/save the session
        NotificationCenter.default.post(name: NSNotification.Name("SaveSession"), object: nil)
    }

    @objc private func toggleSidebar() {
        // Post notification to toggle sidebar visibility
        // This will be handled by the main ContentView
        NotificationCenter.default.post(name: NSNotification.Name("ToggleSidebar"), object: nil)
    }

    @objc private func showDashboard() {
        // Post notification to navigate to Dashboard
        NotificationCenter.default.post(name: NSNotification.Name("NavigateTo"), object: "dashboard")
    }

    @objc private func showSessions() {
        // Post notification to navigate to Sessions
        NotificationCenter.default.post(name: NSNotification.Name("NavigateTo"), object: "sessions")
    }

    @objc private func showProjects() {
        // Post notification to navigate to Projects
        NotificationCenter.default.post(name: NSNotification.Name("NavigateTo"), object: "projects")
    }

    @objc private func showSystem() {
        // Post notification to navigate to System
        NotificationCenter.default.post(name: NSNotification.Name("NavigateTo"), object: "system")
    }

    @objc private func showBrowser() {
        // Post notification to navigate to Browser
        NotificationCenter.default.post(name: NSNotification.Name("NavigateTo"), object: "browser")
    }

    @objc private func showSettings() {
        // Post notification to navigate to Settings
        NotificationCenter.default.post(name: NSNotification.Name("NavigateTo"), object: "settings")
    }
}
