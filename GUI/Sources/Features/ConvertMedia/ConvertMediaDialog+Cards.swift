//
//  File.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

extension ConvertMediaDialog {

    var headerBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Convert Media")
                    .font(.headline)
                Text("Select target format and output location.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Layout.hPad)
        .padding(.vertical, 8)
        .background(headerBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHPad)
    }



    var sourceCard: some View {
        HStack(spacing: 10) {
            Image(systemName: sourceFormat?.systemImage ?? "doc")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Source")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(file.nameStr)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.urlValue.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            if let sourceFormat {
                Text(sourceFormat.displayName)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(sourceFormatBadgeBackground)
            }
        }
        .padding(.horizontal, Layout.hPad)
        .padding(.vertical, 10)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHPad)
    }


    var targetCard: some View {
        HStack(spacing: 10) {
            Image(systemName: targetFormat.systemImage)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Convert to")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Picker("", selection: $targetFormat) {
                    ForEach(availableFormats) { format in
                        Label(format.displayName, systemImage: format.systemImage).tag(format)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
            Spacer()
        }
        .padding(.horizontal, Layout.hPad)
        .padding(.vertical, 10)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHPad)
    }


    var outputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text("OUTPUT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("Filename", text: $outputName)
                            .textFieldStyle(.roundedBorder)
                            .focused($isNameFieldFocused)
                            .onSubmit {
                                if isValid {
                                    performConvert()
                                }
                            }
                        Text(".\(targetFormat.fileExtension)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                Text(outputDir)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer()
                Button {
                    chooseOutputDir()
                } label: {
                    Text("Choose…")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                .background(choiceButtonBackground)
                .overlay(choiceButtonBorder)
            }
        }
        .padding(.horizontal, Layout.hPad)
        .padding(.vertical, 10)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHPad)
    }


    var toolStatusBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(toolInfo)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, Layout.hPad + 4)
    }


    var buttonBar: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(ThemedButtonStyle())
            .controlSize(.large)
            Button("Convert") {
                performConvert()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(ThemedButtonStyle())
            .controlSize(.large)
            .disabled(!isValid)
        }
        .padding(.horizontal, Layout.compactHPad)
        .padding(.bottom, 10)
    }



    var sourceFormatBadgeBackground: some View {
        RoundedRectangle(cornerRadius: Layout.chipCornerRadius, style: .continuous)
            .fill(Color.accentColor.opacity(0.12))
    }



    var choiceButtonBackground: some View {
        RoundedRectangle(cornerRadius: Layout.chipCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Layout.sectionTintOpacity)))
    }



    var choiceButtonBorder: some View {
        RoundedRectangle(cornerRadius: Layout.chipCornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Layout.borderOpacity), lineWidth: Layout.borderLineWidth)
    }


    var panelBackground: some View {
        RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Layout.panelTintOpacity)))
    }


    var panelBorder: some View {
        RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Layout.borderOpacity), lineWidth: Layout.borderLineWidth)
    }


    var headerBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Layout.headerTintOpacity)))
    }


    var sectionBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Layout.sectionTintOpacity)))
    }



    var sectionBorder: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Layout.borderOpacity), lineWidth: Layout.borderLineWidth)
    }


    var windowConfigurator: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                configureHostingWindowIfNeeded()
            }
    }
}
