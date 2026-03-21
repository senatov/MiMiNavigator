// FileInfoPopup.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: File metadata HUD popup.
//   FileInfoButton  — small orange ▶ trigger shown on selected+truncated row.
//   FileInfoPopupController — inherits all panel/show/hide from InfoPopupController,
//   only owns buildContent(for:) and date fetching.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - FileInfoButton
/// Green triangle at right edge of Name column.
/// Visible when row is selected AND file name is truncated.
struct FileInfoButton: View {
    let file: CustomFile
    let isSelected: Bool

    @State private var isTruncated = false
    @State private var anchorFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            geometryObserver(geo: geo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            fileInfoIndicator
        }
    }

    // MARK: - Indicator
    @ViewBuilder
    private var fileInfoIndicator: some View {
        if isSelected && isTruncated {
            Button {
                FileInfoPopupController.shared.show(
                    content: FileInfoPopupController.shared.buildContent(for: file),
                    anchorFrame: anchorFrame
                )
            } label: {
                turquoiseIndicator
            }
            .buttonStyle(.plain)
            .help("File Info")
            .transition(.opacity.combined(with: .scale(scale: 0.6)))
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
    }

    private var turquoiseIndicator: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 0.2, green: 0.8, blue: 0.75))
                .frame(width: 6)
                .shadow(color: Color.black.opacity(0.25), radius: 2, x: -1, y: 0)

            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                .frame(width: 6)
        }
        .frame(width: 10, height: 18)
        .contentShape(Rectangle())
    }

    private func geometryObserver(geo: GeometryProxy) -> some View {
        Color.clear
            .onAppear {
                updateGeometry(geo)
            }
            .onChange(of: geo.size.width) { _, _ in
                updateGeometry(geo)
            }
            .onChange(of: geo.frame(in: .global)) { _, frame in
                anchorFrame = frame
            }
    }

    private func updateGeometry(_ geo: GeometryProxy) {
        anchorFrame = geo.frame(in: .global)
        checkTruncation(width: geo.size.width)
    }

    private func checkTruncation(width: CGFloat) {
        let font = NSFont.systemFont(ofSize: 13, weight: .regular)
        isTruncated = (file.nameStr as NSString).size(withAttributes: [.font: font]).width > width
    }
}

