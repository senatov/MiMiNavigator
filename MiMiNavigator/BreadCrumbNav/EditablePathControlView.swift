import AppKit
import SwiftUI
import SwiftyBeaver

/// A view displaying a breadcrumb-style editable path bar with panel navigation menus.
struct EditablePathControlView: View {
    @EnvironmentObject var appState: AppState

    // MARK: -
    var body: some View {
        log.info(#function)
        return HStack(spacing: 2) {
            NavMnu1()
            Spacer(minLength: 3)
            BreadCrumbView(side: appState.focusedSide)
                .environmentObject(appState)
            NavMnu2()
        }
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.background)
        )
    }


    // MARK: - Builds an array of breadcrumb items based on the currently selected file entity.
    private func getPathItems() -> [EditablePathItem] {
        log.info(#function)
        guard let url = getPathURL() else {
            log.warning("URL is nil, returning empty breadcrumb")
            return []
        }
        let items = createEditablePathItems(from: url)
        log.info("Breadcrumb items count: \(items.count)")
        return items
    }

    // MARK: - Converts a URL into breadcrumb items with titles and icons.
    private func createEditablePathItems(from url: URL) -> [EditablePathItem] {
        log.info(#function + " for URL: \(url.path)")
        var items: [EditablePathItem] = []
        var components = url.pathComponents

        if components.first == "/" && components.count > 1 {
            components.removeFirst()
        }
        var currentPath = url.isFileURL && url.path.hasPrefix("/") ? "/" : ""
        for component in components where !component.isEmpty {
            currentPath = (currentPath as NSString).appendingPathComponent(component)
            let icon = NSWorkspace.shared.icon(forFile: currentPath)
            icon.size = NSSize(width: 16, height: 16)
            let displayTitle = currentPath == "/" ? "Macintosh HD" : component

            let item = EditablePathItem(titleStr: displayTitle, pathStr: currentPath, icon: icon)
            items.append(item)
        }
        return items
    }


    // MARK: -  Retrieves the URL from the currently selected file entity.
    private func getPathURL() -> URL? {
        log.info(#function)
        guard
            let selected = appState.focusedSide == .left
                ? appState.selectedLeftFile
                : appState.selectedRightFile
        else {
            log.warning("No file selected for side \(appState.focusedSide)")
            return nil
        }
        return selected.urlValue
    }
}
