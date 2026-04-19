//
//  MediaInfoPanel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Descr: unified media panel — info, preview, sibling navigation and convert.

import AppKit
import AVFoundation
import AVKit
import FileModelKit
import ImageIO
import SwiftyBeaver
import UniformTypeIdentifiers

@MainActor
final class MediaInfoPanel: NSObject, ObservableObject {

    private let log = SwiftyBeaver.self

    static let shared = MediaInfoPanel()

    enum PreviewMode {
        case none
        case image
        case video
    }

    enum PreviewConstants {
        static let iconSize = NSSize(width: 128, height: 128)
    }

    enum LayoutConstants {
        static let panelSize = NSSize(width: 1020, height: 680)
        static let minPanelSize = NSSize(width: 820, height: 540)
        static let frameAutosaveName = "MiMiNavigator.MediaInfoWindow"
    }

    enum PreferenceKeys {
        static let targetFormat = "MediaInfoPanel.targetFormat"
        static let deleteOriginal = "MediaInfoPanel.deleteOriginal"
        static let outputDirectory = "MediaInfoPanel.outputDirectory"
    }

    static let supportedImageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "ico", "svg",
    ]
    static let supportedVideoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "ts", "webm"]
    static let supportedAudioExtensions: Set<String> = ["mp3", "aac", "flac", "wav", "m4a", "ogg", "wma", "aiff", "alac"]
    static let supportedMediaExtensions =
        supportedImageExtensions
        .union(supportedVideoExtensions)
        .union(supportedAudioExtensions)

    var panel: NSPanel?
    var playerView: AVPlayerView?
    var player: AVPlayer?

    @Published var rawText: String = ""
    @Published var displayTitle: String = "Media􀅴 & Convert"
    @Published var previewImage: NSImage?
    @Published var previewMode: PreviewMode = .none
    @Published var isAnimatedImagePreview: Bool = false
    @Published var currentVideoURL: URL?
    @Published var currentURL: URL?
    @Published var currentCoordinates: (Double, Double)?
    @Published var targetFormat: MediaFormat = .mp4 {
        didSet { persistPreferences() }
    }
    @Published var outputName: String = ""
    @Published var outputDir: String = "" {
        didSet { persistPreferences() }
    }
    @Published var availableFormats: [MediaFormat] = []
    @Published var deleteOriginal: Bool = false {
        didSet { persistPreferences() }
    }

    var mediaFiles: [URL] = []
    var currentIndex = 0
    var panelCreated = false
    var currentPanelSide: FavPanelSide = .left
    weak var appState: AppState?

    private override init() {
        super.init()
    }

    func show(
        title: String,
        text: String,
        url: URL? = nil,
        coordinates: (Double, Double)? = nil,
        panelSide: FavPanelSide? = nil,
        appState: AppState? = nil
    ) {
        log.debug(#function)
        ensurePanelExists()
        displayTitle = title
        rawText = text
        currentURL = url
        currentCoordinates = coordinates ?? extractCoordinates(from: text)
        self.appState = appState ?? self.appState ?? AppStateProvider.shared
        currentPanelSide = panelSide ?? self.appState?.focusedPanel ?? currentPanelSide

        if let url {
            configureConversionState(for: url)
            loadMediaSiblings(for: url)
            updatePreview(for: url)
        }

        log.debug("[MediaInfoPanel] show url=\(url?.path ?? "nil")")
        positionPanelIfNeeded()
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeKey()
    }

    func update(title: String, text: String) {
        update(title: title, text: text, coordinates: nil)
    }

    func update(title: String, text: String, coordinates: (Double, Double)?) {
        log.debug("[MediaInfoPanel] update title=\(title)")
        displayTitle = title
        rawText = text
        currentCoordinates = coordinates ?? extractCoordinates(from: text)
    }

    func hide() {
        stopVideoPlayback()
        panel?.orderOut(nil)
    }

    func bringToFront() {
        guard panel?.isVisible == true else { return }
        panel?.orderFront(nil)
    }

    func ensurePanelExists() {
        if panel == nil {
            createPanel()
        }
    }

    func positionPanelIfNeeded() {
        guard !panelCreated, let panel else { return }
        panelCreated = true

        if !panel.setFrameUsingName(LayoutConstants.frameAutosaveName) {
            panel.setFrame(defaultFrame(), display: true)
        }
        panel.setFrameAutosaveName(LayoutConstants.frameAutosaveName)
    }

    func refreshText(title: String, text: String) {
        displayTitle = title
        rawText = text
    }

    var outputURL: URL {
        URL(fileURLWithPath: outputDir)
            .appendingPathComponent(outputName)
            .appendingPathExtension(targetFormat.fileExtension)
    }

    var sourceFormat: MediaFormat? {
        guard let currentURL else { return nil }
        return MediaFormat.from(extension: currentURL.pathExtension.lowercased())
    }

    var isConvertible: Bool {
        sourceFormat != nil && !availableFormats.isEmpty
    }

    var isValidConversion: Bool {
        isConvertible && !outputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var toolInfo: String {
        guard let sourceFormat else { return "" }
        let tool = MediaFormat.requiredTool(from: sourceFormat, to: targetFormat)
        return tool.isAvailable ? "\(tool.rawValue) • available" : "\(tool.rawValue) • not installed"
    }

    func configureConversionState(for url: URL) {
        let detectedSourceFormat = MediaFormat.from(extension: url.pathExtension.lowercased())
        let targetFormats = detectedSourceFormat.map { MediaFormat.targets(for: $0) } ?? []
        availableFormats = targetFormats

        if let stored = storedTargetFormat(), targetFormats.contains(stored) {
            targetFormat = stored
        } else if let first = targetFormats.first {
            targetFormat = first
        }

        outputName = url.deletingPathExtension().lastPathComponent
        if let storedOutputDirectory = UserDefaults.standard.string(forKey: PreferenceKeys.outputDirectory),
           FileManager.default.fileExists(atPath: storedOutputDirectory) {
            outputDir = storedOutputDirectory
        } else {
            outputDir = url.deletingLastPathComponent().path
        }
        deleteOriginal = UserDefaults.standard.bool(forKey: PreferenceKeys.deleteOriginal)
    }

    func chooseOutputDir() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Choose"
        openPanel.directoryURL = URL(fileURLWithPath: outputDir)
        if openPanel.runModal() == .OK, let url = openPanel.url {
            outputDir = url.path
        }
    }

    func performConvert() {
        guard isValidConversion, let currentURL else { return }
        let currentFile = CustomFile(path: currentURL.path)
        let resolvedAppState = appState ?? AppStateProvider.shared
        guard let resolvedAppState else { return }

        Task {
            await CntMenuCoord.shared.performMediaConversion(
                file: currentFile,
                targetFormat: targetFormat,
                outputURL: outputURL,
                panel: currentPanelSide,
                appState: resolvedAppState,
                deleteOriginal: deleteOriginal
            )
        }
    }

    func defaultFrame() -> NSRect {
        let size = LayoutConstants.panelSize
        if let main = NSApp.mainWindow {
            let frame = main.frame
            return NSRect(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        }
        if let screen = NSScreen.main?.visibleFrame {
            return NSRect(
                x: screen.midX - size.width / 2,
                y: screen.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        }
        return NSRect(origin: .zero, size: size)
    }

    func persistPreferences() {
        UserDefaults.standard.set(targetFormat.rawValue, forKey: PreferenceKeys.targetFormat)
        UserDefaults.standard.set(deleteOriginal, forKey: PreferenceKeys.deleteOriginal)
        if !outputDir.isEmpty {
            UserDefaults.standard.set(outputDir, forKey: PreferenceKeys.outputDirectory)
        }
    }

    func storedTargetFormat() -> MediaFormat? {
        guard let rawValue = UserDefaults.standard.string(forKey: PreferenceKeys.targetFormat) else {
            return nil
        }
        return MediaFormat(rawValue: rawValue)
    }

    func isAnimatedImage(at url: URL) -> Bool {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return false
        }
        return CGImageSourceGetCount(imageSource) > 1
    }
}
