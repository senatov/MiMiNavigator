// NetworkDeviceInfoPopup.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.02.2026.
// Copyright 2026 Senatov. All rights reserved.
// Description: Device info popup for any network host.
//   - MAC vendor lookup via api.macvendors.com (free, no key)
//   - Printer info via IPP (port 631)

import NetworkKit
import SwiftUI

// MARK: - NetworkDeviceInfoPopup
struct NetworkDeviceInfoPopup: View {
    let host: NetworkHost

    @State private var entries: [DeviceInfoEntry] = []
    @State private var isLoading = true

    private enum Layout {
        static let popupWidth: CGFloat = 340
        static let cornerRadius: CGFloat = 14
        static let sectionCornerRadius: CGFloat = 12
        static let headerHPadding: CGFloat = 12
        static let rowHPadding: CGFloat = 12
        static let labelWidth: CGFloat = 90
        static let dividerInset: CGFloat = 102
    }

    // MARK: - Glass Styling
    @ViewBuilder
    private var popupBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .fill(.clear)
    }

    @ViewBuilder
    private var popupBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    @ViewBuilder
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
    }

    @ViewBuilder
    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
    }

    @ViewBuilder
    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(sectionBackground)
            .overlay(sectionBorder)
            .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func tintedSectionCard<Content: View>(
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
            .overlay(sectionBorder)
            .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var loadingSection: some View {
        sectionCard {
            ProgressView()
                .padding(20)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            popupHeader

            if isLoading {
                loadingSection
            } else {
                infoRows
            }
        }
        .frame(width: Layout.popupWidth)
        .padding(.top, 10)
        .background(popupBackground)
        .glassEffect(.regular)
        .overlay(popupBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .task { await loadInfo() }
    }

    private var popupHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: host.systemIconName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(host.hostDisplayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(host.deviceClass.label.isEmpty ? host.nodeTypeLabel : host.deviceClass.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Layout.headerHPadding)
        .padding(.vertical, 10)
        .background {
            tintedSectionCard(tint: iconColor) {
                Color.clear
            }
        }
        .padding(.horizontal, 10)
    }

    private var infoRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                infoRow(entry)

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, Layout.dividerInset)
                }
            }
        }
        .padding(.vertical, 4)
        .background {
            sectionCard {
                Color.clear
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func infoRow(_ entry: DeviceInfoEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: Layout.labelWidth, alignment: .trailing)
            Text(entry.value)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.rowHPadding)
        .padding(.vertical, 4)
    }

    // MARK: - Load device info async (never blocks MainActor)
    private func loadInfo() async {
        entries = await NetworkDeviceInfoLoader(host: host).load()
        isLoading = false
    }

    private var iconColor: Color {
        switch host.deviceClass {
            case .mac:
                return .blue
            case .router, .repeater, .networkSwitch:
                return .orange
            case .printer:
                return .purple
            case .nas:
                return .green
            case .appleMobile, .iPhone, .iPad, .androidPhone, .androidTablet:
                return .teal
            case .windowsPC:
                return .indigo
            case .linuxServer:
                return .mint
            case .smartTV, .mediaBox, .gameConsole:
                return .pink
            case .camera:
                return .red
            default:
                return .secondary
        }
    }
}
