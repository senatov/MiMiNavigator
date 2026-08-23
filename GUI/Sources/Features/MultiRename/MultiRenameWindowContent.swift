// MultiRenameWindowContent.swift
// MiMiNavigator

import SwiftUI

// MARK: - Multi Rename Window Content

struct MultiRenameWindowContent: View {
    @Bindable var viewModel: MultiRenameViewModel

    private enum Layout {
        static let minWidth: CGFloat = 680
        static let minHeight: CGFloat = 480
        static let outerCornerRadius: CGFloat = 14
        static let sectionCornerRadius: CGFloat = 12
        static let horizontalPadding: CGFloat = 10
        static let outerSpacing: CGFloat = 10
        static let borderLineWidth: CGFloat = 0.8
    }

    private var itemCountText: String {
        let count = viewModel.previewItems.count
        return count == 1 ? "1 item" : "\(count) items"
    }

    private var statusText: String {
        if viewModel.isRenaming { return "Renaming…" }
        if viewModel.canRename { return "\(itemCountText), ready" }
        return "\(itemCountText), no changes"
    }

    var body: some View {
        VStack(spacing: Layout.outerSpacing) {
            headerBar
            rulesSection
            previewSection
            footerBar
        }
        .frame(minWidth: Layout.minWidth, minHeight: Layout.minHeight)
        .keyboardFocusSection()
        .forcedDialogTabNavigation()
        .padding(.top, 10)
        .background(panelBackground)
        .glassEffect(.regular)
        .overlay(panelBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous))
        .font(.system(size: 12))
        .inAppNoticeHost(scope: .multiRename)
        .onChange(of: viewModel.errorMessage) { _, message in
            guard let message else { return }
            InAppNoticeCenter.shared.showBanner(title: "Multi-Rename Error", message: message, scope: .multiRename)
            viewModel.errorMessage = nil
        }
        .onChange(of: viewModel.completionMessage) { _, message in
            guard let message else { return }
            InAppNoticeCenter.shared.showToast(message, scope: .multiRename)
            viewModel.completionMessage = nil
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Multi-Rename Tool")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "text.line.2.summary")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(#colorLiteral(red: 0.2470588235, green: 0.0784313725, blue: 0.3921568627, alpha: 1.0)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.horizontalPadding)
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        MultiRenameRulesView(viewModel: viewModel)
            .background(sectionBackground)
            .overlay(sectionBorder)
            .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
            .padding(.horizontal, Layout.horizontalPadding)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Preview")
                .padding(.top, 10)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            MultiRenamePreviewView(items: viewModel.previewItems)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(maxHeight: .infinity)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.horizontalPadding)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Text(itemCountText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reset") { viewModel.reset() }
                .buttonStyle(ThemedButtonStyle())
            Button("Close") { MultiRenameCoordinator.shared.close() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(ThemedButtonStyle())
            Button("Rename") { viewModel.rename() }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canRename)
                .buttonStyle(ThemedButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, 10)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.8)
        }
    }

    // MARK: - Panel Background

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous)
            .fill(.clear)
    }

    // MARK: - Panel Border

    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: Layout.borderLineWidth)
    }

    // MARK: - Section Background

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
    }

    // MARK: - Section Border

    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: Layout.borderLineWidth)
    }
}
