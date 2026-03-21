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

    // MARK: - Glass drop indicator
    private var turquoiseIndicator: some View {
        GlassDropShape()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.45, green: 0.78, blue: 1.00).opacity(0.92), location: 0.0),
                        .init(color: Color(red: 0.18, green: 0.52, blue: 0.95).opacity(0.80), location: 0.55),
                        .init(color: Color(red: 0.10, green: 0.38, blue: 0.82).opacity(0.88), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                GlassDropShape()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.55), location: 0.0),
                                .init(color: Color.white.opacity(0.0),  location: 0.45)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 1)
                    .padding(.top, 1)
            }
            .overlay {
                GlassDropShape()
                    .stroke(Color.white.opacity(0.30), lineWidth: 0.5)
            }
            .shadow(color: Color(red: 0.10, green: 0.38, blue: 0.90).opacity(0.45), radius: 3, x: -1, y: 1)
            .frame(width: 9, height: 20)
            .contentShape(Rectangle())
    }

    // MARK: - GlassDropShape
    /// Teardrop flush to right edge: rounded on left/top/bottom, flat on right.
    private struct GlassDropShape: Shape {
        // MARK: - path
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let r: CGFloat = rect.width * 0.72
            let tipR: CGFloat = 2.0
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY + tipR))
            p.addArc(
                center: CGPoint(x: rect.maxX - tipR, y: rect.minY + tipR),
                radius: tipR, startAngle: .degrees(-90), endAngle: .degrees(0),
                clockwise: true
            )
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tipR))
            p.addArc(
                center: CGPoint(x: rect.maxX - tipR, y: rect.maxY - tipR),
                radius: tipR, startAngle: .degrees(0), endAngle: .degrees(90),
                clockwise: false
            )
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX - r, y: rect.midY),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX - tipR, y: rect.minY + tipR),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
            p.closeSubpath()
            return p
        }
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

