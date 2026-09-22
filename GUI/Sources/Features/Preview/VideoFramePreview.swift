// VideoFramePreview.swift
// MiMiNavigator
// Description: Still-frame fallback for video formats without a Quick Look generator.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Video Frame Preview
enum VideoFramePreview {
    static let fallbackExtensions: Set<String> = ["webm", "mkv", "avi", "flv", "wmv", "ts"]

    static func supports(_ url: URL) -> Bool {
        fallbackExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Extract Frame
    static func image(for url: URL, edge: Int) async -> NSImage? {
        guard supports(url), FileManager.default.isExecutableFile(atPath: ConversionTool.ffmpegPath) else { return nil }
        let data = await Task.detached(priority: .utility) {
            extractFrame(from: url, edge: edge, seconds: 1)
                ?? extractFrame(from: url, edge: edge, seconds: 0)
        }.value
        return data.flatMap(NSImage.init(data:))
    }

    private nonisolated static func extractFrame(from url: URL, edge: Int, seconds: Int) -> Data? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: ConversionTool.ffmpegPath)
        process.arguments = ["-hide_banner", "-loglevel", "error", "-nostdin", "-ss", String(seconds), "-i", url.path,
                             "-frames:v", "1", "-vf", "scale=\(max(1, edge)):\(max(1, edge)):force_original_aspect_ratio=decrease",
                             "-f", "image2pipe", "-vcodec", "png", "pipe:1"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return data
        } catch {
            return nil
        }
    }
}

// MARK: - Video Frame Preview View
struct VideoFramePreviewView: View {
    let url: URL
    @State private var image: NSImage?
    @State private var loading = true

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
            } else if loading {
                ProgressView()
            } else {
                ContentUnavailableView("Preview unavailable", systemImage: "film", description: Text("A video frame could not be read."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .task(id: url) {
            image = nil
            loading = true
            let result = await VideoFramePreview.image(for: url, edge: 1200)
            guard !Task.isCancelled else { return }
            image = result
            loading = false
        }
    }
}
