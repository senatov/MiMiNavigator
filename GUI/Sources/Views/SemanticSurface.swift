// SemanticSurface.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared semantic headers, cards, and dialog regions.

import SwiftUI

// MARK: - Semantic Surface Style
struct SemanticSurfaceStyle: ViewModifier {
    var cornerRadius: CGFloat = DesignTokens.Radius.card
    var isRaised = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(reduceTransparency ? DialogColors.light : DialogColors.light.opacity(0.82))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DialogColors.border.opacity(0.72), lineWidth: DesignTokens.Control.borderWidth)
            }
            .shadow(color: .black.opacity(isRaised ? 0.12 : 0.06), radius: isRaised ? 5 : 2, y: isRaised ? 2 : 1)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let systemImage: String?
    let subtitle: String?
    init(_ title: String, systemImage: String? = nil, subtitle: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
    }
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.compact) {
            HStack(spacing: DesignTokens.Spacing.related) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.label)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(.primary)
            }
            if let subtitle {
                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Status Card
struct StatusCard<Actions: View>: View {
    enum Kind {
        case neutral
        case empty
        case warning
        case error
        var tint: Color {
            switch self {
            case .neutral: return .accentColor
            case .empty: return .secondary
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
    let title: String
    let message: String?
    let systemImage: String
    let kind: Kind
    @ViewBuilder let actions: () -> Actions
    init(
        title: String,
        message: String? = nil,
        systemImage: String,
        kind: Kind = .neutral,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.kind = kind
        self.actions = actions
    }
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.related) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(kind.tint)
                .frame(width: 48, height: 48)
                .background(kind.tint.opacity(0.09), in: Circle())
                .overlay { Circle().strokeBorder(kind.tint.opacity(0.22), lineWidth: DesignTokens.Control.borderWidth) }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            if let message {
                Text(message)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            actions()
        }
        .padding(.horizontal, DesignTokens.Spacing.container)
        .padding(.vertical, DesignTokens.Spacing.section)
        .semanticSurface(isRaised: true)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Empty Status Card
extension StatusCard where Actions == EmptyView {
    init(title: String, message: String? = nil, systemImage: String, kind: Kind = .neutral) {
        self.init(title: title, message: message, systemImage: systemImage, kind: kind) { EmptyView() }
    }
}

// MARK: - Dialog Footer
struct DialogFooter<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.related) {
            Divider()
            HStack(spacing: DesignTokens.Dialog.footerSpacing) {
                Spacer(minLength: 0)
                content()
            }
        }
        .padding(.top, DesignTokens.Spacing.compact)
    }
}

// MARK: - Semantic Surface Extension
extension View {
    func semanticSurface(cornerRadius: CGFloat = DesignTokens.Radius.card, isRaised: Bool = false) -> some View {
        modifier(SemanticSurfaceStyle(cornerRadius: cornerRadius, isRaised: isRaised))
    }
}
