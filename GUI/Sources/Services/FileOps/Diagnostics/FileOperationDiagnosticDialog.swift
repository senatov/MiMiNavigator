import SwiftUI

struct FileOperationDiagnosticDialog: View {
    let info: FileOperationDiagnosticInfo
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            header
            summary
            details
            actions
        }
        .padding(16)
        .frame(width: 500)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.clear)
        )
        .glassEffect(.regular)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.8)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.orange)

            Text(info.title)
                .font(.system(size: 14, weight: .semibold))

            Spacer()
        }
    }

    private var summary: some View {
        Text(info.summary)
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var details: some View {
        ScrollView {
            Text(info.details)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 90, maxHeight: 180)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.8)
        )
    }

    private var actions: some View {
        HStack {
            Spacer()
            DownToolbarButtonView(
                title: "OK",
                systemImage: "checkmark.circle",
                action: onClose
            )
        }
    }
}
