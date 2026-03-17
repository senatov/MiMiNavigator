// SettingsColorsHelpers.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared UI helpers for all Colors sub-panes.
//   Extracted so each pane stays small and focused (Nova/Xcode pattern).

import AppKit
import SwiftUI

// MARK: - Shared color-pane helpers (mixin via protocol + extension)
protocol ColorPaneHelpers: View {}

extension ColorPaneHelpers {

    // MARK: - swatch
    func swatch(_ color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 18, height: 14)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.1), lineWidth: 0.5))
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - sectionHeader
    func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .textCase(.uppercase)
            Spacer()
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.5))
                .frame(height: 0.5)
                .padding(.leading, 8)
        }
        .padding(.top, 10)
        .padding(.bottom, 5)
    }

    // MARK: - rowLabel
    func rowLabel<C: View>(_ label: String, help: String, @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 190, alignment: .trailing)
                .help(help)
            Spacer().frame(width: 14)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }

    // MARK: - paneGroupBox
    func paneGroupBox<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DialogColors.light))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DialogColors.border.opacity(0.45), lineWidth: 0.5))
    }

    // MARK: - colorRow
    func colorRow(_ label: String, help: String, preset: Color, hex: Binding<String>, store: ColorThemeStore) -> some View {
        rowLabel(label + ":", help: help) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(preset)
                    .frame(width: 22, height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.12), lineWidth: 0.5))
                    .help("Preset default")
                Text("→").foregroundStyle(.tertiary).font(.system(size: 11))
                ColorPicker("", selection: colorBinding(hex: hex, fallback: preset, store: store))
                    .labelsHidden().frame(width: 28)
                if !hex.wrappedValue.isEmpty {
                    Button { hex.wrappedValue = ""; store.reloadOverrides() } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 10))
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Reset to preset default")
                }
            }
        }
    }

    // MARK: - sliderRow
    func sliderRow(_ label: String, help: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double,
                   displayFormat: String = "%.2f", unit: String = "", onChange: @escaping () -> Void) -> some View {
        rowLabel(label + ":", help: help) {
            HStack(spacing: 10) {
                Slider(value: value, in: range, step: step).frame(width: 130)
                    .onChange(of: value.wrappedValue) { _, _ in onChange() }
                Text(String(format: displayFormat, value.wrappedValue) + unit)
                    .monospacedDigit().foregroundStyle(.secondary).frame(width: 48, alignment: .leading)
            }
        }
    }

    // MARK: - colorBinding
    private func colorBinding(hex: Binding<String>, fallback: Color, store: ColorThemeStore) -> Binding<Color> {
        Binding<Color>(
            get: { hex.wrappedValue.isEmpty ? fallback : Color(hex: hex.wrappedValue) ?? fallback },
            set: { newColor in hex.wrappedValue = newColor.toHex() ?? ""; store.reloadOverrides() }
        )
    }

    // MARK: - resetButton
    func resetButton(action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button("Reset to Default", action: action)
                .buttonStyle(ThemedButtonStyle()).tint(.red)
        }
        .padding(.top, 8)
    }
}
