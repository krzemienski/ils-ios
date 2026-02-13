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
            action: #selector(NSResponder.undo(_:)),
            keyEquivalent: "z"
        )
        editMenu.addItem(undoItem)

        // Redo (Cmd+Shift+Z)
        let redoItem = NSMenuItem(
            title: "Redo",
            action: #selector(NSResponder.redo(_:)),
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
}
