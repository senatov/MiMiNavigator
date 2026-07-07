// MultiRenameWindowContent.swift
// MiMiNavigator

import SwiftUI

// MARK: - Multi Rename Window Content
struct MultiRenameWindowContent: View {
    @Bindable var viewModel: MultiRenameViewModel

    private var dialogBackground: Color {
        let store = ColorThemeStore.shared
        if !store.hexDialogBackground.isEmpty, let color = Color(hex: store.hexDialogBackground) { return color }
        return store.activeTheme.dialogBackground
    }

    var body: some View {
        ZStack {
            dialogBackground.ignoresSafeArea()
            VStack(spacing: 10) {
                MultiRenameRulesView(viewModel: viewModel)
                MultiRenamePreviewView(items: viewModel.previewItems)
                    .frame(maxHeight: .infinity)
                HStack {
                    Text("\(viewModel.previewItems.count) item(s)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset") { viewModel.reset() }
                    Button("Close") { MultiRenameCoordinator.shared.close() }
                        .keyboardShortcut(.cancelAction)
                    Button("Rename") { viewModel.rename() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!viewModel.canRename)
                }
            }
            .padding(12)
            .font(.system(size: 12))
            .keyboardFocusSection()
            .forcedDialogTabNavigation()
            .alert("Multi-Rename Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
