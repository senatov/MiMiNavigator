// MediaInfoPanelView+Preview.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Media preview surface and bottom action presentation.

import SwiftUI

// MARK: - Preview Presentation
extension MediaInfoPanelView {
    var previewCard: some View {
        Group {
            switch controller.previewMode {
                case .image:
                    if let image = controller.previewImage {
                        if controller.isAnimatedImagePreview {
                            MediaInfoAnimatedImagePreview(image: image)
                        } else {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        previewPlaceholder
                    }
                case .video:
                    MediaInfoVideoPreview(controller: controller)
                case .none:
                    previewPlaceholder
            }
        }
        .frame(minWidth: Layout.previewMinWidth, idealWidth: Layout.previewIdealWidth, maxWidth: .infinity, maxHeight: .infinity)
        .background(sectionBackground)
        .overlay(previewBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
    }

    private var previewBorder: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .strokeBorder(previewBorderColor, lineWidth: 1)
    }

    private var previewBorderColor: Color {
        switch controller.previewMode {
        case .video:
            return Color(nsColor: #colorLiteral(red: 0.0431372549, green: 0.2941176471, blue: 0.1450980392, alpha: 1))
        case .image:
            return Color(nsColor: #colorLiteral(red: 0, green: 0.4784313725, blue: 1, alpha: 1))
        case .none:
            return Color(nsColor: .separatorColor)
        }
    }

    private var previewPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Preview unavailable")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions
    var buttonBar: some View {
        HStack(spacing: Layout.bottomButtonSpacing) {
            DownToolbarButtonView(title: "Copy Path", systemImage: "link", action: controller.copyPathAction)
            DownToolbarButtonView(title: "Copy All", systemImage: "doc.on.doc", action: controller.copyAllAction)
            Spacer()
            DownToolbarButtonView(title: "Reveal", systemImage: "folder", action: controller.revealAction)
            DownToolbarButtonView(title: "Close", systemImage: "xmark.circle", action: controller.closeAction)
        }
        .padding(.horizontal, Layout.compactHorizontalPadding)
        .padding(.bottom, 10)
        .fixedSize(horizontal: false, vertical: true)
    }
}
