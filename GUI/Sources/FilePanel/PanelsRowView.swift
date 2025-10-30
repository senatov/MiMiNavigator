import SwiftUI

    // MARK: - Hosts two file panels inside native NSSplitView (SplitContainer)
struct PanelsRowView: View {
    @EnvironmentObject var appState: AppState
    
        // MARK: - Left panel width persisted across runs
    @AppStorage("leftPanelWidth") private var leftPanelWidthValue: Double = 420
    
        // MARK: -
    var leftPanelWidth: CGFloat {
        get { CGFloat(leftPanelWidthValue) }
        set { leftPanelWidthValue = Double(newValue) }
    }
    
        // MARK: - Files loader for a specific side
    var fetchFiles: @Sendable @concurrent (PanelSide) async -> Void
    
        // MARK: -
    var body: some View {
        SplitContainer(
            leftPanel: {
                GeometryReader { gp in
                    FilePanelView(
                        selectedSide: .left,
                        geometry: gp,
                        containerSize: gp.size,
                        leftPanelWidth: Binding<CGFloat>(
                            get: { CGFloat(leftPanelWidthValue) },
                            set: { leftPanelWidthValue = Double($0) }
                        ),
                        fetchFiles: fetchFiles,
                        appState: appState
                    )
                    .id("panel-left")
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded {
                                if appState.focusedPanel != .left {
                                    appState.focusedPanel = .left
                                    appState.forceFocusSelection()
                                    log.debug("PanelsRowView: focus → .left via tap")
                                } else {
                                    log.debug("PanelsRowView: tap on .left ignored (already focused)")
                                }
                            }
                    )
                }
            },
            rightPanel: {
                GeometryReader { gp in
                    FilePanelView(
                        selectedSide: .right,
                        geometry: gp,
                        containerSize: gp.size,
                        leftPanelWidth: Binding<CGFloat>(
                            get: { CGFloat(leftPanelWidthValue) },
                            set: { leftPanelWidthValue = Double($0) }
                        ),
                        fetchFiles: fetchFiles,
                        appState: appState
                    )
                    .id("panel-right")
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded {
                                if appState.focusedPanel != .right {
                                    appState.focusedPanel = .right
                                    appState.forceFocusSelection()
                                    log.debug("PanelsRowView: focus → .right via tap")
                                } else {
                                    log.debug("PanelsRowView: tap on .right ignored (already focused)")
                                }
                            }
                    )
                }
            },
            leftPanelWidth: Binding<CGFloat>(
                get: { CGFloat(leftPanelWidthValue) },
                set: { leftPanelWidthValue = Double($0) }
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped(antialiased: true)
        .transaction { $0.disablesAnimations = true }
        .animation(nil, value: appState.focusedPanel)
        .onAppear { log.debug("PanelsRowView → using NSSplitView (SplitContainer)") }
    }
}
