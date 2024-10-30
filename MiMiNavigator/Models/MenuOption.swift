
import Foundation

// Define the structure of a menu option
struct MenuOption: Identifiable {
    let id = UUID()
    let name: String
    var children: [MenuOption]? = nil
}

// Initialize menu options
let menuOptions: [MenuOption] = [
    MenuOption(name: "Configuration", children: [
        MenuOption(name: "Options"),
        MenuOption(name: "Display"),
        MenuOption(name: "Layout"),
        MenuOption(name: "Colors"),
        MenuOption(name: "Fonts"),
    ]),
    MenuOption(name: "Files", children: [
        MenuOption(name: "Associate"),
        MenuOption(name: "Edit/View"),
        MenuOption(name: "Compare"),
        MenuOption(name: "Sync Dirs"),
    ]),
    MenuOption(name: "Network", children: [
        MenuOption(name: "FTP Connect"),
        MenuOption(name: "FTP Disconnect"),
        MenuOption(name: "Network Neighborhood"),
    ]),
    MenuOption(name: "Tools", children: [
        MenuOption(name: "Multi-Rename Tool"),
        MenuOption(name: "Disk Cleanup"),
        MenuOption(name: "Compare by Content"),
    ]),
]
